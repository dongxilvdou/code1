extends Node
var player: AudioStreamPlayer

func _ready() -> void:
	player=AudioStreamPlayer.new();player.volume_db=-20;add_child(player)

func play_feedback(kind: String) -> void:
	var frequencies: Dictionary={"open":440.0,"confirm":660.0,"error":180.0,"relay":95.0,"pulse":880.0,"record":523.25}
	var sample:=AudioStreamWAV.new();sample.format=AudioStreamWAV.FORMAT_16_BITS;sample.mix_rate=22050
	var data:=PackedByteArray();var length:=3307;data.resize(length*2)
	for i in range(length):
		var t:=i/22050.0;var envelope:=sin(float(i)/length*PI)*exp(-t*12)
		var value:=int(sin(t*TAU*float(frequencies.get(kind,440.0)))*envelope*10000)
		data.encode_s16(i*2,value)
	sample.data=data;player.stream=sample;player.play()
