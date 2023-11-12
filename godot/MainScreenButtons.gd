extends Control

var confirm = false

func _ready():
	pass 
	
#func _process(delta):
#	pass


func _on_EmbarkButton_mouse_entered():
	$EmbarkButton/Overlay.visible = false


func _on_EmbarkButton_mouse_exited():
	$EmbarkButton/Overlay.visible = true


func _on_CardsButton_mouse_entered():
	$CardsButton/Overlay.visible = false


func _on_CardsButton_mouse_exited():
	$CardsButton/Overlay.visible = true


func _on_ParameciaButton_mouse_entered():
	$ParameciaButton/Overlay.visible = false


func _on_ParameciaButton_mouse_exited():
	$ParameciaButton/Overlay.visible = true


func _on_NodeButton_mouse_entered():
	$NodeButton/Overlay.visible = false


func _on_NodeButton_mouse_exited():
	$NodeButton/Overlay.visible = true


func _on_OptionsButton_mouse_entered():
	$OptionsButton/Overlay.visible = false


func _on_OptionsButton_mouse_exited():
	$OptionsButton/Overlay.visible = true


func _on_CavesButton_mouse_entered():
	get_parent().get_node("EmbarkMenu/CavesButton/Overlay").visible = false
	get_parent().get_node("EmbarkMenu/CavesName").visible = true


func _on_CavesButton_mouse_exited():
	if confirm == false:
		get_parent().get_node("EmbarkMenu/CavesButton/Overlay").visible = true
		get_parent().get_node("EmbarkMenu/CavesName").visible = false


func _on_CraterButton_mouse_entered():
	get_parent().get_node("EmbarkMenu/CraterButton/Overlay").visible = false
	get_parent().get_node("EmbarkMenu/CraterName").visible = true
	


func _on_CraterButton_mouse_exited():
	if confirm == false:
		get_parent().get_node("EmbarkMenu/CraterButton/Overlay").visible = true
		get_parent().get_node("EmbarkMenu/CraterName").visible = false


func _on_PrecipiceButton_mouse_entered():
	get_parent().get_node("EmbarkMenu/PrecipiceButton/Overlay").visible = false
	get_parent().get_node("EmbarkMenu/PrecipiceName").visible = true


func _on_PrecipiceButton_mouse_exited():
	if confirm == false:
		get_parent().get_node("EmbarkMenu/PrecipiceButton/Overlay").visible = true
		get_parent().get_node("EmbarkMenu/PrecipiceName").visible = false
