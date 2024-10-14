package main

import "core:fmt"
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

execute :: proc(self: ^Emulator) {
	inst, X, Y, N, NN, NNN := decode(self)

	switch inst {
	case 0x0:
		switch Y {
		case 0xE:
			switch NN {
			case 0x0:
				for x := 0; x < SCREEN_HEIGHT; x += 1 {
					for y := 0; y < SCREEN_WIDTH; y += 1 {
						self.screen[x][y] = 0
					}
				}
			}
		case 0x1:
			self.pc = NNN
		case 0x6:
			self.registers[X] = NN
		case 0x7:
			self.registers[X] += NN
		case 0xA:
			self.I = NNN
		case 0xD:
			drawSprite(self, X, Y, N)
		case:
			fmt.printf("Unhandled op %v \n", inst)
		}
	}
}

image: rl.Image
texture: rl.Texture2D

draw :: proc(self: ^Emulator) {
	for x := 0; x < SCREEN_WIDTH; x += 1 {
		for y := 0; y < SCREEN_HEIGHT; y += 1 {
			if (self.screen[x][y] > 0) {
				rl.ImageDrawPixel(&image, cast(i32)x, cast(i32)y, rl.WHITE)
			}
		}
	}
}


drawSprite :: proc(self: ^Emulator, VX, VY, N: u8) {
	x := VX % SCREEN_WIDTH
	y := VY % SCREEN_HEIGHT
	self.registers[0xF] = 0
	for row := 0; row < cast(int)N; row += 1 {
		spriteByte: u8 = self.memory[cast(int)self.I + row]
		for col := 0; col < cast(int)N; col += 1 {
			if spriteByte & (0x80 >> cast(u8)col) != 0 {
				pixelX := (x + cast(u8)col) % cast(u8)SCREEN_WIDTH
				pixelY := (y + cast(u8)row) % cast(u8)SCREEN_HEIGHT
				if self.screen[pixelX][pixelY] == 1 {
					self.registers[0xF] = 1
				}

				self.screen[pixelX][pixelY] ~= 1
			}
		}

	}
}

main :: proc() {
	emulator: ^Emulator = new(Emulator)

	rl.InitWindow(SCREEN_WIDTH * SCALE, SCREEN_HEIGHT * SCALE, "Chip8-Interpreter-Odin")
	rl.SetTargetFPS(60)

	image = rl.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLACK)
	texture = rl.LoadTextureFromImage(image)
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
		execute(emulator)
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
