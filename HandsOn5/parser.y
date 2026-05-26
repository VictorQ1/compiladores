%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
int yyerror(char *s);

extern FILE *yyin;
extern int   yylineno;   /* línea actual, proporcionada por %option yylineno */

/* ════════════════════════════════════════════════════════════
   TABLA DE SÍMBOLOS
   ════════════════════════════════════════════════════════════ */
#define MAX_SIMB 300

#define TIPO_VAR   0
#define TIPO_FUNC  1
#define TIPO_MACRO 2
#define TIPO_PARAM 3   /* parámetros formales de función */

#define TIPO_INT 0

typedef struct {
    char *nombre;
    int   clase;
    int   tipo_dato;
    int   aridad;
    int   ambito;
    int   activo;
    int   usado;    /* 7.2: campo para detectar variables no usadas */
} Simbolo;

Simbolo tabla[MAX_SIMB];

int ntabla              = 0;
int ambito_actual       = 0;
int semantic_errors     = 0;
int func_nueva          = 0;  /* 1 si la función actual fue añadida con éxito */

/* ────────────────────────────────────────────────────────────
   6.3  Error sintáctico con número de línea
   ──────────────────────────────────────────────────────────── */
int yyerror(char *s) {
    printf("Error sintáctico en línea %d: %s\n", yylineno, s);
    return 0;
}

/* ════════════════════════════════════════════════════════════
   GESTIÓN DE ÁMBITOS
   ════════════════════════════════════════════════════════════ */
void entrar_ambito() {
    ambito_actual++;
}

void salir_ambito() {
    for (int i = 0; i < ntabla; i++)
        if (tabla[i].ambito == ambito_actual)
            tabla[i].activo = 0;
    ambito_actual--;
}

/* ════════════════════════════════════════════════════════════
   BÚSQUEDAS EN LA TABLA
   ════════════════════════════════════════════════════════════ */
int existe_en_ambito_actual(char *id) {
    for (int i = 0; i < ntabla; i++)
        if (tabla[i].activo &&
            tabla[i].ambito == ambito_actual &&
            strcmp(tabla[i].nombre, id) == 0)
            return 1;
    return 0;
}

int existe_global(char *id, int clase) {
    for (int i = 0; i < ntabla; i++)
        if (tabla[i].activo      &&
            tabla[i].ambito == 0 &&
            tabla[i].clase  == clase &&
            strcmp(tabla[i].nombre, id) == 0)
            return 1;
    return 0;
}

/* Busca variable/parámetro visible desde el ámbito actual */
int buscar_tipo_variable(char *id) {
    for (int a = ambito_actual; a >= 0; a--)
        for (int i = ntabla - 1; i >= 0; i--)
            if (tabla[i].activo &&
                (tabla[i].clase == TIPO_VAR || tabla[i].clase == TIPO_PARAM) &&
                tabla[i].ambito == a &&
                strcmp(tabla[i].nombre, id) == 0)
                return tabla[i].tipo_dato;
    return -1;
}

int buscar_aridad_funcion(char *id) {
    for (int i = 0; i < ntabla; i++)
        if (tabla[i].activo &&
            tabla[i].clase == TIPO_FUNC &&
            strcmp(tabla[i].nombre, id) == 0)
            return tabla[i].aridad;
    return -1;
}

/* ════════════════════════════════════════════════════════════
   7.2  MARCADO DE USO
   ════════════════════════════════════════════════════════════ */
void marcar_usado(char *id) {
    for (int a = ambito_actual; a >= 0; a--)
        for (int i = ntabla - 1; i >= 0; i--)
            if (tabla[i].activo &&
                (tabla[i].clase == TIPO_VAR || tabla[i].clase == TIPO_PARAM) &&
                tabla[i].ambito == a &&
                strcmp(tabla[i].nombre, id) == 0) {
                tabla[i].usado = 1;
                return;
            }
}

/* ════════════════════════════════════════════════════════════
   AGREGAR SÍMBOLOS
   ════════════════════════════════════════════════════════════ */
void agregar_variable(char *id, int tipo_dato) {
    if (existe_en_ambito_actual(id)) {
        printf("Error semántico en línea %d: redeclaración de variable '%s'\n",
               yylineno, id);
        semantic_errors++;
        return;
    }
    tabla[ntabla++] = (Simbolo){strdup(id), TIPO_VAR, tipo_dato,
                                0, ambito_actual, 1, 0};
}

void agregar_parametro(char *id, int tipo_dato) {
    if (existe_en_ambito_actual(id)) {
        printf("Error semántico en línea %d: redeclaración de parámetro '%s'\n",
               yylineno, id);
        semantic_errors++;
        return;
    }
    tabla[ntabla++] = (Simbolo){strdup(id), TIPO_PARAM, tipo_dato,
                                0, ambito_actual, 1, 0};
}

void agregar_macro(char *id) {
    if (existe_global(id, TIPO_MACRO)) {
        printf("Error semántico en línea %d: macro '%s' ya definida\n",
               yylineno, id);
        semantic_errors++;
        return;
    }
    tabla[ntabla++] = (Simbolo){strdup(id), TIPO_MACRO, TIPO_INT,
                                0, 0, 1, 0};
}

void agregar_funcion(char *id, int aridad) {
    if (existe_global(id, TIPO_FUNC)) {
        printf("Error semántico en línea %d: función '%s' ya declarada\n",
               yylineno, id);
        semantic_errors++;
        func_nueva = 0;   /* redeclaración: no actualizar aridad después */
        return;
    }
    tabla[ntabla++] = (Simbolo){strdup(id), TIPO_FUNC, TIPO_INT,
                                aridad, 0, 1, 0};
    func_nueva = 1;
}

/* ════════════════════════════════════════════════════════════
   VERIFICACIONES SEMÁNTICAS
   ════════════════════════════════════════════════════════════ */

/* Verifica que un identificador esté declarado y lo marca como usado */
void verificar_uso_variable(char *id) {
    if (buscar_tipo_variable(id) == -1) {
        printf("Error semántico en línea %d: variable '%s' no declarada\n",
               yylineno, id);
        semantic_errors++;
    } else {
        marcar_usado(id);
    }
}

void verificar_llamada_funcion(char *id, int argumentos) {
    int esperados = buscar_aridad_funcion(id);
    if (esperados == -1) {
        printf("Error semántico en línea %d: función '%s' no declarada\n",
               yylineno, id);
        semantic_errors++;
        return;
    }
    if (esperados != argumentos) {
        printf("Error semántico en línea %d: función '%s' espera %d "
               "argumento(s), pero recibió %d\n",
               yylineno, id, esperados, argumentos);
        semantic_errors++;
    }
}

/* ════════════════════════════════════════════════════════════
   7.1  IMPRIMIR TABLA DE SÍMBOLOS
   ════════════════════════════════════════════════════════════ */
void imprimir_tabla() {
    printf("\n+---------------+----------+-------+--------+--------+\n");
    printf("| %-13s | %-8s | %-5s | %-6s | %-6s |\n",
           "Nombre", "Clase", "Tipo", "Ámbito", "Aridad");
    printf("+---------------+----------+-------+--------+--------+\n");

    for (int i = 0; i < ntabla; i++) {
        char *clase_str;
        switch (tabla[i].clase) {
            case TIPO_VAR:   clase_str = "variable"; break;
            case TIPO_FUNC:  clase_str = "funcion";  break;
            case TIPO_MACRO: clase_str = "macro";    break;
            case TIPO_PARAM: clase_str = "param";    break;
            default:         clase_str = "?";
        }

        char aridad_str[8];
        if (tabla[i].clase == TIPO_FUNC)
            sprintf(aridad_str, "%d", tabla[i].aridad);
        else
            strcpy(aridad_str, "-");

        printf("| %-13s | %-8s | %-5s | %-6d | %-6s |\n",
               tabla[i].nombre, clase_str, "int",
               tabla[i].ambito, aridad_str);
    }
    printf("+---------------+----------+-------+--------+--------+\n");
}

/* ════════════════════════════════════════════════════════════
   7.2  DETECTAR VARIABLES DECLARADAS PERO NO USADAS
        Solo aplica a TIPO_VAR en ámbitos locales (ambito > 0)
   ════════════════════════════════════════════════════════════ */
void verificar_no_usadas() {
    printf("\n");
    for (int i = 0; i < ntabla; i++)
        if (tabla[i].clase  == TIPO_VAR &&
            tabla[i].ambito  > 0        &&
            !tabla[i].usado)
            printf("Advertencia: variable '%s' declarada pero no usada\n",
                   tabla[i].nombre);
}

%}

/* ════════════════════════════════════════════════════════════
   UNIÓN Y TOKENS
   ════════════════════════════════════════════════════════════ */
%union {
    char *str;
    int   num;
}

%token <str> ID
%token <str> STRING_LITERAL
%token <str> NUMBER

%token INCLUDE DEFINE
%token INT FUNC RETURN IF
%token IGUAL
%token PARIZQ PARDER LLAVEIZQ LLAVEDER PUNTOYCOMA COMA
%token MENOR MAYOR PUNTO
%token PLUS MINUS TIMES DIVIDE   /* 5.3 operadores aritméticos */

%type <num> parametros lista_param argumentos lista_args
%type <str> expr

%%

/* ════════════════════════════════════════════════════════════
   GRAMÁTICA
   ════════════════════════════════════════════════════════════ */

programa:
      preprocesador declaraciones
      {
          /* 7.1 */ imprimir_tabla();
          /* 7.2 */ verificar_no_usadas();

          if (semantic_errors == 0)
              printf("\nAnálisis completado sin errores semánticos.\n");
          else
              printf("\nAnálisis completado con %d error(es) semántico(s).\n",
                     semantic_errors);
      }
    ;

/* ── Preprocesador ──────────────────────────────────────── */
preprocesador:
      preprocesador directiva
    | /* vacío */
    ;

directiva:
      include
    | define
    ;

include:
      INCLUDE MENOR ID MAYOR
    | INCLUDE MENOR ID PUNTO ID MAYOR
    | INCLUDE STRING_LITERAL
    ;

define:
      DEFINE ID NUMBER         { agregar_macro($2); }
    | DEFINE ID ID             { agregar_macro($2); }
    | DEFINE ID STRING_LITERAL { agregar_macro($2); }
    | DEFINE ID                { agregar_macro($2); }
    ;

/* ── Declaraciones globales ─────────────────────────────── */
declaraciones:
      declaracion
    | declaraciones declaracion
    ;

declaracion:
      INT ID PUNTOYCOMA
      {
          agregar_variable($2, TIPO_INT);
      }
    | FUNC ID PARIZQ
      {
          agregar_funcion($2, -1);
          entrar_ambito();           /* ámbito de función */
      }
      parametros PARDER bloque_funcion
      {
          int aridad = $5;
          /* solo actualizar si la función fue declarada por primera vez */
          if (func_nueva) {
              for (int i = 0; i < ntabla; i++)
                  if (tabla[i].activo &&
                      tabla[i].clase == TIPO_FUNC &&
                      strcmp(tabla[i].nombre, $2) == 0) {
                      tabla[i].aridad = aridad;
                      break;
                  }
          }
          salir_ambito();
      }
    ;

/* ── Parámetros formales ────────────────────────────────── */
parametros:
      /* vacío */ { $$ = 0; }
    | lista_param { $$ = $1; }
    ;

lista_param:
      ID
      {
          agregar_parametro($1, TIPO_INT);
          $$ = 1;
      }
    | lista_param COMA ID
      {
          agregar_parametro($3, TIPO_INT);
          $$ = $1 + 1;
      }
    ;

/* ── Cuerpo de función (ya estamos dentro del ámbito) ───── */
bloque_funcion:
      LLAVEIZQ instrucciones LLAVEDER
    ;

/* ── Bloque anidado — crea su propio ámbito ─────────────── */
bloque:
      LLAVEIZQ
      { entrar_ambito(); }
      instrucciones
      LLAVEDER
      { salir_ambito(); }
    ;

/* ── Lista de instrucciones ─────────────────────────────── */
instrucciones:
      instrucciones instruccion
    | /* vacío */
    ;

/* ── Instrucción ────────────────────────────────────────── */
instruccion:
      /* declaración local */
      INT ID PUNTOYCOMA
      {
          agregar_variable($2, TIPO_INT);
      }

      /* 6.1 asignación con expresión aritmética */
    | ID IGUAL expr PUNTOYCOMA
      {
          if (buscar_tipo_variable($1) == -1) {
              printf("Error semántico en línea %d: variable '%s' no declarada\n",
                     yylineno, $1);
              semantic_errors++;
          }
          /* las variables del lado derecho ya se verificaron en expr */
      }

      /* llamada a función */
    | ID PARIZQ argumentos PARDER PUNTOYCOMA
      {
          verificar_llamada_funcion($1, $3);
      }

      /* return con expresión */
    | RETURN expr PUNTOYCOMA
      { /* las variables de expr ya se verificaron */ }

      /* 6.2 sentencia if simple */
    | IF PARIZQ ID PARDER bloque
      {
          /* 7.3 verificar que la condición esté declarada */
          if (buscar_tipo_variable($3) == -1) {
              printf("Error semántico en línea %d: variable '%s' no declarada\n",
                     yylineno, $3);
              semantic_errors++;
          } else {
              marcar_usado($3);
          }
      }

      /* bloque anidado sin if */
    | bloque
    ;

/* ── 6.1 Expresiones aritméticas simples ────────────────── */
expr:
      ID
      {
          verificar_uso_variable($1);
          $$ = $1;
      }
    | NUMBER
      {
          $$ = $1;
      }
    | ID PLUS ID
      {
          verificar_uso_variable($1);
          verificar_uso_variable($3);
          $$ = $1;
      }
    | ID MINUS ID
      {
          verificar_uso_variable($1);
          verificar_uso_variable($3);
          $$ = $1;
      }
    | ID TIMES ID
      {
          verificar_uso_variable($1);
          verificar_uso_variable($3);
          $$ = $1;
      }
    | ID DIVIDE ID
      {
          verificar_uso_variable($1);
          verificar_uso_variable($3);
          $$ = $1;
      }
    ;

/* ── Argumentos de llamada ──────────────────────────────── */
argumentos:
      /* vacío */ { $$ = 0; }
    | lista_args  { $$ = $1; }
    ;

lista_args:
      ID
      {
          verificar_uso_variable($1);
          $$ = 1;
      }
    | lista_args COMA ID
      {
          verificar_uso_variable($3);
          $$ = $1 + 1;
      }
    ;

%%

/* ════════════════════════════════════════════════════════════
   PUNTO DE ENTRADA
   ════════════════════════════════════════════════════════════ */
int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Uso: %s archivo_fuente\n", argv[0]);
        return EXIT_FAILURE;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        printf("Error: no se pudo abrir el archivo '%s'\n", argv[1]);
        return EXIT_FAILURE;
    }

    yyparse();
    fclose(yyin);

    return semantic_errors == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
