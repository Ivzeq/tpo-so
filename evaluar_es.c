#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/sysmacros.h>
#include <sys/utsname.h>

#define MAX_LINEAS 512
#define LARGO_LINEA 160

/* Muestra un archivo con open/read/write */
void mostrar(const char *ruta) {
    char buf[512];
    ssize_t n;
    int fd = open(ruta, O_RDONLY);
    if (fd < 0) { perror(ruta); return; }
    while ((n = read(fd, buf, sizeof(buf))) > 0)
        if (write(STDOUT_FILENO, buf, n) < 0) break;
    close(fd);
}

/* Parte 1: clasifica dispositivos de /dev como bloque o caracter */
void clasificar(void) {
    const char *devs[] = {"/dev/sda", "/dev/vda", "/dev/null",
                          "/dev/zero", "/dev/tty0", "/dev/ttyS0"};
    struct stat st;
    for (int i = 0; i < 6; i++) {
        if (stat(devs[i], &st) < 0) continue;
        const char *clase = S_ISBLK(st.st_mode) ? "bloque" :
                            S_ISCHR(st.st_mode) ? "caracter" : "otro";
        printf("%-12s %-9s mayor=%u menor=%u\n", devs[i], clase,
               major(st.st_rdev), minor(st.st_rdev));
    }
}

/* Parte 2: guarda una foto de /proc/ioports en un archivo */
void guardar_foto(const char *destino) {
    char buf[512];
    ssize_t n;
    int org = open("/proc/ioports", O_RDONLY);
    int dst = open(destino, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (org < 0 || dst < 0) { perror("guardar_foto"); return; }
    while ((n = read(org, buf, sizeof(buf))) > 0)
        if (write(dst, buf, n) < 0) break;
    close(org);
    close(dst);
    printf("Foto guardada en %s\n", destino);
}

int leer_lineas(const char *ruta, char l[][LARGO_LINEA]) {
    FILE *f = fopen(ruta, "r");
    int n = 0;
    if (!f) { perror(ruta); return -1; }
    while (n < MAX_LINEAS && fgets(l[n], LARGO_LINEA, f)) n++;
    fclose(f);
    return n;
}

int esta(const char *linea, char l[][LARGO_LINEA], int n) {
    for (int i = 0; i < n; i++)
        if (strcmp(linea, l[i]) == 0) return 1;
    return 0;
}

/* Compara las fotos: + puerto nuevo, - puerto que ya no esta */
void comparar_fotos(void) {
    static char a[MAX_LINEAS][LARGO_LINEA], d[MAX_LINEAS][LARGO_LINEA];
    int na = leer_lineas("ioports_antes.txt", a);
    int nd = leer_lineas("ioports_despues.txt", d);
    int cambios = 0;
    if (na < 0 || nd < 0) return;
    for (int i = 0; i < nd; i++)
        if (!esta(d[i], a, na)) { printf("+ %s", d[i]); cambios++; }
    for (int i = 0; i < na; i++)
        if (!esta(a[i], d, nd)) { printf("- %s", a[i]); cambios++; }
    if (!cambios) printf("Sin diferencias en los puertos.\n");
}

/* Busca un numero mayor en /proc/devices (drivers registrados) */
int mayor_registrado(unsigned mayor) {
    FILE *f = fopen("/proc/devices", "r");
    char linea[LARGO_LINEA], nombre[64];
    unsigned m;
    if (!f) return 0;
    while (fgets(linea, sizeof(linea), f))
        if (sscanf(linea, "%u %63s", &m, nombre) == 2 && m == mayor) {
            printf("Mayor %u registrado por el driver '%s'\n", mayor, nombre);
            fclose(f);
            return 1;
        }
    fclose(f);
    return 0;
}

/* Parte 2: crea un dispositivo virtual de caracter y verifica si tiene driver */
void crear_virtual(void) {
    const char *ruta = "/dev/mio";
    unsigned mayor = 240;
    if (mknod(ruta, S_IFCHR | 0666, makedev(mayor, 0)) < 0 && errno != EEXIST) {
        perror("mknod (ejecutar con sudo)");
        return;
    }
    printf("Nodo %s creado (mayor %u, menor 0)\n", ruta, mayor);
    if (!mayor_registrado(mayor))
        printf("El mayor %u no tiene driver en /proc/devices\n", mayor);
    int fd = open(ruta, O_RDONLY);
    if (fd < 0) {
        printf("open(%s): %s\n", ruta, strerror(errno));
    } else {
        printf("open(%s) correcto\n", ruta);
        close(fd);
    }
}

/* Parte 3: lista los drivers (modulos) cargados */
void listar_modulos(void) {
    FILE *f = fopen("/proc/modules", "r");
    char linea[LARGO_LINEA], nombre[64];
    unsigned long tam;
    int uso, n = 0;
    if (!f) { perror("/proc/modules"); return; }
    printf("%-20s %-10s %s\n", "DRIVER", "TAMANIO", "EN USO");
    while (n < 15 && fgets(linea, sizeof(linea), f))
        if (sscanf(linea, "%63s %lu %d", nombre, &tam, &uso) == 3) {
            printf("%-20s %-10lu %d\n", nombre, tam, uso);
            n++;
        }
    fclose(f);
}

/* Parte 3: registra la version del kernel y del driver en un log */
void registrar_version(void) {
    char modulo[64], ruta[160], version[64] = "sin version", fecha[32];
    struct utsname u;
    time_t t = time(NULL);
    printf("Nombre del driver (modulo): ");
    if (scanf("%63s", modulo) != 1) return;
    snprintf(ruta, sizeof(ruta), "/sys/module/%s/version", modulo);
    FILE *v = fopen(ruta, "r");
    if (v) {
        if (fgets(version, sizeof(version), v))
            version[strcspn(version, "\n")] = 0;
        fclose(v);
    }
    uname(&u);
    strftime(fecha, sizeof(fecha), "%Y-%m-%d %H:%M", localtime(&t));
    FILE *log = fopen("actualizaciones.log", "a");
    if (!log) { perror("actualizaciones.log"); return; }
    fprintf(log, "%s | kernel %s | %s | version %s\n", fecha, u.release, modulo, version);
    fclose(log);
    printf("Registrado: %s | kernel %s | %s | version %s\n", fecha, u.release, modulo, version);
}

int main() {
    int op;
    do {
        printf("\n1. Clasificar dispositivos (bloque/caracter)\n"
               "2. Ver puertos de E/S (/proc/ioports)\n"
               "3. Guardar foto de puertos: antes\n"
               "4. Guardar foto de puertos: despues\n"
               "5. Comparar fotos\n"
               "6. Crear dispositivo virtual\n"
               "7. Ver drivers cargados\n"
               "8. Registrar version de un driver\n"
               "0. Salir\nOpcion: ");
        if (scanf("%d", &op) != 1) break;
        switch (op) {
            case 1: clasificar(); break;
            case 2: mostrar("/proc/ioports"); break;
            case 3: guardar_foto("ioports_antes.txt"); break;
            case 4: guardar_foto("ioports_despues.txt"); break;
            case 5: comparar_fotos(); break;
            case 6: crear_virtual(); break;
            case 7: listar_modulos(); break;
            case 8: registrar_version(); break;
        }
    } while (op != 0);
    return 0;
}
