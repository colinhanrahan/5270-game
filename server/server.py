import asyncio
import json
import random
import string
import websockets

import cairocffi as cairo   # used by original preprocessing, remove?
import numpy as np
import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path="quickdraw_model.tflite")
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input shape:", input_details[0]['shape'])
print("Input dtype:", input_details[0]['dtype'])

with open("labels.txt") as f:
    labels = [line.strip() for line in f.readlines()]
print(f"Loaded {len(labels)} labels")

rooms = {}  # code: websocket

def make_code():
    return ''.join(random.choices(string.ascii_uppercase, k=6))

async def handler(websocket):
    room_code = None
    try:
        async for raw in websocket:
            msg = json.loads(raw)
            kind = msg["type"]
            if kind == "create":
                room_code = make_code()
                rooms[room_code] = {websocket}
                await websocket.send(json.dumps({"type": "created", "code": room_code}))
            elif kind == "join":
                room_code = msg["code"].upper()
                if room_code not in rooms:
                    await websocket.send(json.dumps({"type": "error", "msg": "Room not found"}))
                    room_code = None
                else:
                    rooms[room_code].add(websocket)
                    await websocket.send(json.dumps({"type": "joined", "code": room_code}))
            elif kind == "broadcast" and room_code:
                peers = rooms[room_code] - {websocket}
                if peers:
                    payload = json.dumps(msg["data"])
                    await asyncio.gather(*[p.send(payload) for p in peers])
            elif kind == "classify":
                await handle_classify(websocket, msg)
    finally:
        if room_code and room_code in rooms:
            rooms[room_code].discard(websocket)
            if not rooms[room_code]:
                del rooms[room_code]

# Python translation of function from Google Quickdraw dataset preprocessing
# https://github.com/googlecreativelab/quickdraw-dataset/issues/19#issuecomment-402247262
def strokes_to_bitmap(strokes, canvas_width, canvas_height, side=28, line_diameter=16, padding=16):
    original_side = 256.0
    
    # normalize stroke coordinates from canvas size to 256x256
    normalized = []
    for stroke in strokes:
        norm = [[p[0] * 256.0 / canvas_width, p[1] * 256.0 / canvas_height] for p in stroke]
        normalized.append(norm)
    
    # center the drawing like the original
    all_x = [p[0] for stroke in normalized for p in stroke]
    all_y = [p[1] for stroke in normalized for p in stroke]
    bbox_max = [max(all_x), max(all_y)]
    offset = [(256.0 - bbox_max[0]) / 2.0, (256.0 - bbox_max[1]) / 2.0]
    centered = [[[p[0] + offset[0], p[1] + offset[1]] for p in stroke] for stroke in normalized]
    
    # original code uses Cairo, this is the easiest way 
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, side, side)
    ctx = cairo.Context(surface)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    ctx.set_line_width(line_diameter)
    
    total_padding = padding * 2.0 + line_diameter
    new_scale = float(side) / float(original_side + total_padding)
    ctx.scale(new_scale, new_scale)
    ctx.translate(total_padding / 2.0, total_padding / 2.0)
    
    # black background
    ctx.set_source_rgb(0, 0, 0)
    ctx.paint()
    
    # white strokes
    ctx.set_source_rgb(1, 1, 1)
    for stroke in centered:
        if len(stroke) < 2:
            continue
        ctx.move_to(stroke[0][0], stroke[0][1])
        for p in stroke[1:]:
            ctx.line_to(p[0], p[1])
        ctx.stroke()
    
    data = surface.get_data()
    bitmap = np.copy(np.asarray(data)[::4])  # take every 4th byte (R channel from ARGB)
    return bitmap

async def handle_classify(websocket, data):
    if not data:
        print("Received empty data")
        return

    strokes = data.get("strokes")
    canvas_width = data.get("width")
    canvas_height = data.get("height")
    
    if not (strokes and canvas_width and canvas_height):
        return
    
    bitmap = strokes_to_bitmap(strokes, canvas_width, canvas_height)
    pixels = bitmap.reshape((1, 28, 28, 1)).astype(np.float32) / 255.0
    
    interpreter.set_tensor(input_details[0]['index'], pixels)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    # TODO: change from top 5 to using raw threshold like Quickdraw
    top5_idx = np.argsort(output[0])[::-1][:5]
    results = [{"label": labels[i], "score": float(output[0][i])} for i in top5_idx]
    await websocket.send(json.dumps({"type": "predictions", "results": results}))

async def main():
    async with websockets.serve(handler, "0.0.0.0", 8765):
        print("Room server running on ws://0.0.0.0:8765")
        await asyncio.Future()

asyncio.run(main())