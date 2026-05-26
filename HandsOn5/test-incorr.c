#include <stdio.h>
#include "util.h"
#define MAX 100
#define MAX 200        // ERROR: macro duplicada

int global;
int global;            // ERROR: variable global redeclarada

func suma(a,b) {
    int resultado;
    resultado = c;     // ERROR: variable 'c' no declarada
    return resultado;
}

func suma(x) {         // ERROR: función 'suma' ya declarada
    return x;
}

func main() {
    int x;
    int y;
    int noUsada;       // será reportada como no usada

    x = y;
    suma(x);           // ERROR: suma espera 2 args, recibió 1
    noExiste(x);       // ERROR: función no declarada

    // ERROR: condicion no está declarada (7.3)
    if (condicion) {
        int z;
        z = x;
    }

    z = x;             // ERROR: z fuera de ámbito

    return noDeclarada; // ERROR: variable no declarada
}
