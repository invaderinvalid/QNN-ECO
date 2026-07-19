to start with this project , the essential point is to not loop the whole process for this reason we will setup it in arduino app lab . to get started you need to go on the official page of arduino app page download the image depending on you os and install it in you system . After installation there are multiple option on top left for adding bricks and libraries . Add "Adafruit PWM servo driver library" in the library add section so the operation of motors can be executed in much streamlined manner . After this you need to all the dependencies for python code . In app lab the normal terminal pip based installation doesnt work , but rather you can add your dependencies into the requirements.txt and app lab will add it automatically . For this project the requirement file is :
opencv-python-headless==4.10.0.84
pyserial
flask
opencv is headless because normal gui version dont work in app lab . 
After this you need to add the face detection model for it , Add this model version-slim-320.onnx into the python directory . Type this if you are a user of linux wget https://github.com/Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB/raw/master/models/onnx/version-slim-320.onnx . after all this copy the project code from the repository it self . Also change your ip webcam ip according to your network . And also remember to stay on the same network when connecting to ip webcam app available on the play store .
project structure :
python :
            -main.py
            -requirements.txt
            -version-slim-320.onnx
sketch :
           -sketch.ino
           -sketch.yaml