extends Node

## Autoload: Google AdMob rewarded + interstitial ads for Android.
## Desktop, editor, and headless runs no-op so tests stay unchanged.
##
## Debug Android builds use Google's test units. Release builds use the live
## DESCENT units. Never click your own live ads.

const APP_ID := "ca-app-pub-3896041129889412~2475413611"
const LIVE_REWARDED_UNIT := "ca-app-pub-3896041129889412/7752926493"
const LIVE_INTERSTITIAL_UNIT := "ca-app-pub-3896041129889412/4799460096"
const TEST_REWARDED_UNIT := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_UNIT := "ca-app-pub-3940256099942544/1033173712"
const REVIVE_HEALTH_FRACTION := 0.5

var _rewarded_ad: RewardedAd
var _interstitial_ad: InterstitialAd
var _rewarded_loader: RewardedAdLoader
var _interstitial_loader: InterstitialAdLoader
var _initialized: bool = false
var _showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_android():
		return
	_update_consent()
	# UMP is a no-op if the native plugin is missing; don't leave ads uninitialized.
	await get_tree().create_timer(2.0).timeout
	_initialize_sdk()


func is_rewarded_ready() -> bool:
	return _rewarded_ad != null and not _showing


func is_interstitial_ready() -> bool:
	return _interstitial_ad != null and not _showing


func present_rewarded() -> bool:
	if not is_rewarded_ready():
		return false
	_showing = true
	var earned := false
	var finished := false
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		earned = true
	_rewarded_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		finished = true
	_rewarded_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err: AdError) -> void:
		finished = true
	_rewarded_ad.show(listener)
	while not finished and is_inside_tree():
		await get_tree().process_frame
	_destroy_rewarded()
	_showing = false
	_load_rewarded()
	return earned


func present_interstitial() -> void:
	if not is_interstitial_ready():
		return
	_showing = true
	var finished := false
	_interstitial_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		finished = true
	_interstitial_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err: AdError) -> void:
		finished = true
	_interstitial_ad.show()
	while not finished and is_inside_tree():
		await get_tree().process_frame
	_destroy_interstitial()
	_showing = false
	_load_interstitial()


func _is_android() -> bool:
	return OS.get_name() == "Android"


func _rewarded_unit() -> String:
	return TEST_REWARDED_UNIT if OS.is_debug_build() else LIVE_REWARDED_UNIT


func _interstitial_unit() -> String:
	return TEST_INTERSTITIAL_UNIT if OS.is_debug_build() else LIVE_INTERSTITIAL_UNIT


func _update_consent() -> void:
	var request := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		request,
		_on_consent_updated,
		func(_error) -> void: _initialize_sdk()
	)


func _on_consent_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if (
		info.get_is_consent_form_available()
		and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED
	):
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, func(_error) -> void: _initialize_sdk())
		return
	_initialize_sdk()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(func(_error) -> void: _initialize_sdk())
		return
	_initialize_sdk()


func _initialize_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	MobileAds.initialize()
	_load_rewarded()
	_load_interstitial()


func _load_rewarded() -> void:
	if not _is_android() or _rewarded_ad != null:
		return
	_rewarded_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("DESCENT ads: rewarded failed to load: %s" % error.message)
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		ad.full_screen_content_callback = FullScreenContentCallback.new()
		_rewarded_ad = ad
	_rewarded_loader.load(_rewarded_unit(), AdRequest.new(), callback)


func _load_interstitial() -> void:
	if not _is_android() or _interstitial_ad != null:
		return
	_interstitial_loader = InterstitialAdLoader.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("DESCENT ads: interstitial failed to load: %s" % error.message)
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		ad.full_screen_content_callback = FullScreenContentCallback.new()
		_interstitial_ad = ad
	_interstitial_loader.load(_interstitial_unit(), AdRequest.new(), callback)


func _destroy_rewarded() -> void:
	if _rewarded_ad == null:
		return
	_rewarded_ad.destroy()
	_rewarded_ad = null


func _destroy_interstitial() -> void:
	if _interstitial_ad == null:
		return
	_interstitial_ad.destroy()
	_interstitial_ad = null
