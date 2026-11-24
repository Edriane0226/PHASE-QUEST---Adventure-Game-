extends "res://Scripts/World/chamber_device_effects.gd"
const ATLAS = preload("res://assets/effects/pressure/v1/atlas.png")
const ART = preload("res://assets/effects/pressure/v1/sprite_frames.tres")
const START = preload("res://assets/audio/Device/pressure_start.wav")
const LOOP = preload("res://assets/audio/Device/pressure_loop.wav")
const RELEASE = preload("res://assets/audio/Device/pressure_release.wav")
func mode_id() -> String: return "pressure"
func art_frames() -> SpriteFrames: return ART
func atlas_texture() -> Texture2D: return ATLAS
func audio_clip(phase: String) -> AudioStreamWAV: return {"start":START,"loop":LOOP,"release":RELEASE}[phase]
