CC := gcc
FLAGS := -Wall -Wextra -fPIC -g
EXECUTABLE:=camera
RM:=rm -f
$(EXECUTABLE):	camera.c
	$(CC) $(FLAGS) $^ -o $@ -ldl

clean:
	$(RM) $(EXECUTABLE)
