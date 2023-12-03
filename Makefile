all:
	odin build . -out:main_plot.exe -extra-linker-flags:"-v"

run:
	./main_plot.exe

clean:
	rm main_plot.exe
