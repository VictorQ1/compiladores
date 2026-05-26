#include <stdio.h>
#include "util.h"
#define MAX 100
#define MENSAJE "hola"

int global;

// Función que suma dos enteros (comentario de línea)
func suma(a,b) {
    int resultado;
    resultado = a + b;   // expresión aritmética
    return resultado;
}

func main() {
    int x;
    int y;

    x = y;
    suma(x,y);

    // bloque if con variable declarada como condición
    if (x) {
        int z;
        z = x;
    }

    return x;
}
