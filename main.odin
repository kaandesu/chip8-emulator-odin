package main

import "core:math"
import rl "vendor:raylib"

SCREEN_WIDTH :: 64
SCREEN_HEIGHT :: 32
SCALE :: 8
MEMORY_OFFSET :: 0x200
STACK_SIZE :: 32
REGISTERS :: 16
MEMORY_SIZE :: 4096

Emulator :: struct {
	registers: [REGISTERS]u8,
	memory:    [MEMORY_SIZE]u8,
	stack:     [STACK_SIZE]u16,
	screen:    [SCREEN_WIDTH][SCREEN_HEIGHT]int,
	sp:        u16,
	I:         u16,
	pc:        u16,
}

fetch :: proc(self: ^Emulator) -> (u8, u8) {
	b0 := self.memory[self.pc]
	b1 := self.memory[self.pc + 1]
	self.pc += 2
	return b0, b1
}

decode :: proc(self: ^Emulator) -> (inst, X, Y, N, NN: u8, NNN: u16) {
	b0, b1 := fetch(self)
	inst = (b0 & 0xF0) >> 4
	X = (b0 & 0x0F)
	Y = (b1 & 0xF0) >> 4
	NN = (b1 & 0x0F)
	NNN = cast(u16)X << 8 | cast(u16)NN
	return
}

main :: proc() {
	emulator: ^Emulator = new(Emulator)

	rl.InitWindow(SCREEN_WIDTH * SCALE, SCREEN_HEIGHT * SCALE, "Chip8-Interpreter-Odin")
	rl.SetTargetFPS(60)

	image := rl.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLACK)
	texture := rl.LoadTextureFromImage(image)
	plane_mesh := rl.GenMeshPlane(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1)
	material := rl.LoadMaterialDefault()
	rl.SetMaterialTexture(&material, rl.MaterialMapIndex.ALBEDO, texture)

	cam: rl.Camera3D = rl.Camera3D {
		position   = rl.Vector3{0.0, 2.0, 10.0},
		target     = rl.Vector3{0.0, 0.0, 0.0},
		up         = rl.Vector3{0.0, 1.0, 0.0},
		fovy       = 60.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}

	for (!rl.WindowShouldClose()) {

		rl.BeginDrawing()
		rl.ClearBackground(rl.GRAY)
		rl.DrawText("Chip8-Interpreter-Odin", 10, 10, 10, rl.WHITE)
		rl.BeginMode3D(cam)

		rl.UpdateTexture(texture, rl.LoadImageColors(image))
		rl.SetMaterialTexture(&material, rl.MaterialMapIndex.ALBEDO, texture)
		rl.DrawCube(rl.Vector3{0, 0, -1}, 15, 9, 1, rl.DARKGRAY)
		rl.DrawMesh(
			plane_mesh,
			material,
			(rl.MatrixRotateX(math.PI / 2) * rl.MatrixScale(0.2, 0.2, 0.2)),
		)
		rl.EndMode3D()
		rl.EndDrawing()
	}

	rl.UnloadTexture(texture)
	rl.UnloadImage(image)
	rl.UnloadMesh(plane_mesh)
	rl.UnloadMaterial(material)
	rl.CloseWindow()
}
