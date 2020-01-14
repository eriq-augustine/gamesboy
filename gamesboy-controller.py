#!/usr/bin/env python3

# Map the GPIO pins for the Gamesboy controller to keyboard events.
# Install with: sudo install gamesboy-controller.py /usr/local/bin/gamesboy-controller

import signal

import gpiozero
import keyboard

# {pin: (game key, keyboard key)}
BUTTON_MAP = {
    26: ('a', 'z'),
    16: ('b', 'x'),

    12: ('up', 'up'),
    6: ('down', 'down'),
    5: ('left', 'left'),
    13: ('right', 'right'),

    22: ('select', 'shift'),
    23: ('start', 'enter'),
}

# Pull floating pins down to 0.
PULL_UP = False

def buttonDown(button):
    pinID = button.pin.number
    (gameKey, keyboardKey) = BUTTON_MAP[pinID]

    # print('Keypress Down: %s (%s) [%d]' % (gameKey, keyboardKey, pinID))

    keyboard.press(keyboardKey)

def buttonUp(button):
    pinID = button.pin.number
    (gameKey, keyboardKey) = BUTTON_MAP[pinID]

    # print('Keypress Up: %s (%s) [%d]' % (gameKey, keyboardKey, pinID))

    keyboard.release(keyboardKey)

def main():
    usedPins = []

    # Setup all the buttons.
    for pinID in BUTTON_MAP:
        button = gpiozero.Button(pinID, pull_up = PULL_UP)

        button.when_pressed = buttonDown
        button.when_released = buttonUp

        usedPins.append(button)

    # Pause the main thread.
    try:
        signal.pause()
    except:
        pass

    for pin in usedPins:
        pin.close()

if (__name__ == '__main__'):
    main()
