class_name DoorDestinationData
extends Resource

## Copy and styling for one of the three post-encounter doors.
## `destination_type` matches RunState.RoomType.

@export var destination_type: int = 1
@export var display_name: String = "LOOT"
@export var description: String = ""
@export var reward: String = ""
@export var risk: String = "LOW RISK"
@export var accent: Color = Color("e2ae52")
