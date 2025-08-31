video: test_fast_zybo.cpp
	g++ -std=c++11 test_fast_zybo.cpp -o test_fast_zybo -I/usr/include/opencv2 -L/usr/lib -lopencv_core -lopencv_imgproc -lopencv_highgui `pkg-config --cflags --libs opencv4`

format:
	clang-format -i *.cpp *.h

clean:
	rm test_fast_zybo *.o