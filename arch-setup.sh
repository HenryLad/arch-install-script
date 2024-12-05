#!/bin/sh


echo "Which keylayout do you want (A to print all options)": 
read keylayout
if [ $keylayout == "A" ]
then
    localectl list-keymaps
    echo "Which keylayout do you want: "
    read keylayout
fi
loadkeys $keylayout
if [ $? -eq 0 ]; then
    echo "Keylayout loaded successfully."
else
    echo "Failed to load keylayout."
fi

