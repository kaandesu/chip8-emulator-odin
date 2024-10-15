package main

import "core:bufio"
import "core:fmt"
import "core:math"
import "core:os"
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
	N = (b1 & 0x0F)
	NN = (b1)
	NNN = (cast(u16)X << 8) | cast(u16)NN
	return
}

execute :: proc(self: ^Emulator) {
	inst, X, Y, N, NN, NNN := decode(self)

	switch inst {
	case 0x0:
		switch Y {
		case 0xE:
			switch N {
			case 0x0:
				self.screen = [64][32]int{}
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
		drawSprite(self, self.registers[X], self.registers[Y], N)
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
		for col := 0; col < 8; col += 1 {
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

	draw(self)
}


loadRom :: proc(self: ^Emulator, filename: string) -> int {
	data, ok := os.read_entire_file(filename, context.allocator)
	if !ok {
		return -1
	}
	defer delete(data, context.allocator)

	for byte, i in data {
		self.memory[i + 0x200] = cast(u8)byte
	}

	return 0
}

main :: proc() {
	emulator: ^Emulator = new(Emulator)
	emulator.pc = MEMORY_OFFSET

	rl.InitWindow(1280, 640, "Chip8-Interpreter-Odin")
	rl.SetTargetFPS(60)

	retroPc := rl.LoadModel("./models/retro_electronics_retro_pc.glb")
	desk := rl.LoadModel("./models/office.glb")
	rot := rl.Vector3{90 * rl.DEG2RAD, 0, 0}
	retroPc.transform = rl.MatrixRotateXYZ(rot)
	desk.transform = rl.MatrixRotateXYZ(
		rl.Vector3{90 * rl.DEG2RAD, 0 * rl.DEG2RAD, 135 * rl.DEG2RAD},
	)

	if err := loadRom(emulator, "./ibm_logo.ch8"); err != 0 {
		// return the number read actually
		panic("Could not read from the ROM")
	}


	image = rl.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, rl.BLACK)
	texture = rl.LoadTextureFromImage(image)
	plane_mesh := rl.GenMeshPlane(SCREEN_WIDTH, SCREEN_HEIGHT, 1, 1)
	material := rl.LoadMaterialDefault()
	rl.SetMaterialTexture(&material, rl.MaterialMapIndex.ALBEDO, texture)
	plane_model := rl.LoadModelFromMesh(plane_mesh)

	plane_model.transform = (rl.MatrixRotateX(math.PI / 2) * rl.MatrixScale(0.2, 0.2, 0.2))

	cam: rl.Camera3D = rl.Camera3D {
		position   = rl.Vector3{1.0, 31.0, 25.0},
		target     = rl.Vector3{0.0, 31.0, 0.0},
		up         = rl.Vector3{0.0, 1.0, 0.0},
		fovy       = 60.0,
		projection = rl.CameraProjection.PERSPECTIVE,
	}

	for (!rl.WindowShouldClose()) {
		rl.UpdateCamera(&cam, rl.CameraMode.FIRST_PERSON)
		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)
		rl.DrawText("Chip8-Interpreter-Odin", 10, 10, 10, rl.WHITE)
		rl.BeginMode3D(cam)
		execute(emulator)
		rl.UpdateTexture(texture, rl.LoadImageColors(image))
		rl.SetMaterialTexture(&plane_model.materials[0], rl.MaterialMapIndex.ALBEDO, texture)
		rl.DrawPlane(rl.Vector3{0, 0, 0}, 200, rl.DARKGRAY)
		rl.DrawModel(desk, rl.Vector3{0, 0.1, 20}, 0.0055, rl.WHITE)
		rl.DrawModel(retroPc, rl.Vector3{0, 18.6, -4.5}, 6.5, rl.WHITE)
		rl.DrawModel(plane_model, rl.Vector3{0, 31.1, 0}, 1, rl.WHITE)
		rl.EndMode3D()
		rl.EndDrawing()
	}

	rl.UnloadTexture(texture)
	rl.UnloadImage(image)
	rl.UnloadMesh(plane_mesh)
	rl.UnloadMaterial(material)
	rl.CloseWindow()
}
