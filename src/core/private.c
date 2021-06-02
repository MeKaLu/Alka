#include <GLFW/glfw3.h>
#include <stb/image.h>

#include <stdbool.h>

bool alkaLoadIcon(GLFWwindow *window, const char* path) {
    GLFWimage images[1]; 
    images[0].pixels = stbi_load(path, &images[0].width, &images[0].height, 0, 4); //rgba channels 
    if (images[0].pixels == NULL) return false;
    glfwSetWindowIcon(window, 1, images); 
    stbi_image_free(images[0].pixels);
    return true;
}
