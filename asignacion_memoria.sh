#!/bin/bash
# =====================================================================
#  asignacion_memoria.sh
#  Sistemas Operativos - TPO - Ejercicio Unidad 3
#  Tema: Estrategias de asignación de memoria a procesos de distintos
#        tamaños (algoritmos de carga, fragmentación externa y
#        compactación).
#
#  Simula una memoria principal con particiones variables. Sobre el
#  mismo estado inicial aplica Primer Ajuste, Mejor Ajuste y Peor
#  Ajuste. Si algún proceso no entra por fragmentación externa, aplica
#  compactación y vuelve a intentar.
#
#  Uso:
#     ./asignacion_memoria.sh            -> ejecuta los tres algoritmos
#     ./asignacion_memoria.sh primer     -> solo Primer Ajuste
#     ./asignacion_memoria.sh mejor      -> solo Mejor Ajuste
#     ./asignacion_memoria.sh peor       -> solo Peor Ajuste
# =====================================================================

# ---------------------------------------------------------------------
# 1. ESTADO INICIAL DE LA MEMORIA (en KB)
#    La memoria se representa como una lista de segmentos contiguos.
#    Cada segmento tiene un DUEÑO y un TAMAÑO:
#      - "LIBRE"  -> hueco disponible
#      - otro     -> zona ocupada (SO o procesos ya cargados)
#    Huecos libres: 100, 500, 200, 300 y 600 KB, separados por procesos
#    que ya estaban en memoria (A, B, C, D).
# ---------------------------------------------------------------------
INI_DUENO=(SO    LIBRE A  LIBRE B  LIBRE C   LIBRE D  LIBRE)
INI_TAM=(  100   100   50 500   80 200   120 300   60 600)

# ---------------------------------------------------------------------
# 2. PROCESOS QUE LLEGAN Y DEBEN CARGARSE (en orden de llegada)
# ---------------------------------------------------------------------
PROC_NOMBRE=(P1  P2  P3  P4)
PROC_TAM=(   212 417 112 426)

# ---------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------

# Copia el estado inicial a la memoria de trabajo (cada algoritmo
# arranca desde la misma situación)
reiniciar_memoria() {
    DUENO=("${INI_DUENO[@]}")
    TAM=("${INI_TAM[@]}")
}

# Dibuja el mapa de memoria con la dirección inicial de cada segmento
mostrar_mapa() {
    local dir=0
    echo "   Inicio    Tamaño    Contenido"
    for i in "${!DUENO[@]}"; do
        local etiqueta=${DUENO[$i]}
        [[ $etiqueta == "LIBRE" ]] && etiqueta="--- libre ---"
        printf "   %-9s %-9s %-10s\n" "$dir" "${TAM[$i]} KB" "$etiqueta"
        dir=$((dir + TAM[i]))
    done
    echo "   Memoria total: $dir KB"
}

# Calcula LIBRE_TOTAL, HUECO_MAYOR y CANT_HUECOS
calcular_libre() {
    LIBRE_TOTAL=0; HUECO_MAYOR=0; CANT_HUECOS=0
    for i in "${!DUENO[@]}"; do
        if [[ ${DUENO[$i]} == "LIBRE" ]]; then
            LIBRE_TOTAL=$((LIBRE_TOTAL + TAM[i]))
            CANT_HUECOS=$((CANT_HUECOS + 1))
            (( TAM[i] > HUECO_MAYOR )) && HUECO_MAYOR=${TAM[$i]}
        fi
    done
}

# ---------------------------------------------------------------------
# ALGORITMO DE CARGA: elige el hueco según la estrategia.
# Devuelve en ELEGIDO el índice del segmento, o -1 si ninguno sirve.
# ---------------------------------------------------------------------
elegir_hueco() {
    local estrategia=$1 tam=$2
    ELEGIDO=-1
    for i in "${!DUENO[@]}"; do
        [[ ${DUENO[$i]} == "LIBRE" ]] || continue     # solo huecos
        (( TAM[i] >= tam )) || continue               # debe entrar
        case $estrategia in
            primer)                                   # el primero que sirve
                ELEGIDO=$i; return ;;
            mejor)                                    # el más chico que sirve
                if (( ELEGIDO == -1 || TAM[i] < TAM[ELEGIDO] )); then ELEGIDO=$i; fi ;;
            peor)                                     # el más grande
                if (( ELEGIDO == -1 || TAM[i] > TAM[ELEGIDO] )); then ELEGIDO=$i; fi ;;
        esac
    done
}

# Carga el proceso en el hueco elegido. Si sobra espacio, el sobrante
# queda como un hueco libre nuevo a continuación (partición variable).
cargar_proceso() {
    local idx=$1 nombre=$2 tam=$3
    local sobrante=$((TAM[idx] - tam))
    DUENO[$idx]=$nombre
    TAM[$idx]=$tam
    if (( sobrante > 0 )); then
        DUENO=("${DUENO[@]:0:idx+1}" "LIBRE" "${DUENO[@]:idx+1}")
        TAM=("${TAM[@]:0:idx+1}" "$sobrante" "${TAM[@]:idx+1}")
    fi
}

# ---------------------------------------------------------------------
# COMPACTACIÓN: mueve todos los segmentos ocupados hacia el inicio de
# la memoria (reubicación) y junta todos los huecos en uno solo al final.
# ---------------------------------------------------------------------
compactar() {
    local nuevo_dueno=() nuevo_tam=() libre=0
    for i in "${!DUENO[@]}"; do
        if [[ ${DUENO[$i]} == "LIBRE" ]]; then
            libre=$((libre + TAM[i]))
        else
            nuevo_dueno+=("${DUENO[$i]}")
            nuevo_tam+=("${TAM[$i]}")
        fi
    done
    DUENO=("${nuevo_dueno[@]}" "LIBRE")
    TAM=("${nuevo_tam[@]}" "$libre")
}

# ---------------------------------------------------------------------
# Simulación completa de una estrategia
# ---------------------------------------------------------------------
simular() {
    local estrategia=$1 titulo=$2
    local pendientes=()
    reiniciar_memoria

    echo
    echo "================================================================"
    echo "  $titulo"
    echo "================================================================"
    echo "   Proceso  Tamaño    Hueco elegido  Sobrante"
    echo "   ---------------------------------------------"

    for p in "${!PROC_NOMBRE[@]}"; do
        local nom=${PROC_NOMBRE[$p]} tam=${PROC_TAM[$p]}
        elegir_hueco "$estrategia" "$tam"
        if (( ELEGIDO == -1 )); then
            printf "   %-8s %-9s %-14s %-10s\n" "$nom" "$tam KB" "NINGUNO" "-"
            pendientes+=("$p")
        else
            local hueco=${TAM[$ELEGIDO]}
            cargar_proceso "$ELEGIDO" "$nom" "$tam"
            printf "   %-8s %-9s %-14s %-10s\n" "$nom" "$tam KB" "$hueco KB" "$((hueco - tam)) KB"
        fi
    done

    echo
    echo "   Mapa de memoria:"
    mostrar_mapa
    calcular_libre
    echo
    echo "   Memoria libre total : $LIBRE_TOTAL KB en $CANT_HUECOS huecos"
    echo "   Hueco libre mayor   : $HUECO_MAYOR KB"
    echo "   Procesos sin cargar : ${#pendientes[@]}"

    local compacto="NO"
    if (( ${#pendientes[@]} > 0 )); then
        local p0=${pendientes[0]}
        if (( LIBRE_TOTAL >= PROC_TAM[p0] )); then
            echo
            echo "   >> FRAGMENTACIÓN EXTERNA: hay $LIBRE_TOTAL KB libres, pero el"
            echo "      hueco contiguo más grande es de $HUECO_MAYOR KB y ${PROC_NOMBRE[$p0]}"
            echo "      necesita ${PROC_TAM[$p0]} KB."
            echo
            echo "   >> Aplicando COMPACTACIÓN..."
            compactar
            compacto="SI"
            echo
            echo "   Mapa de memoria después de compactar:"
            mostrar_mapa
            echo
            local restantes=()
            for p in "${pendientes[@]}"; do
                elegir_hueco "$estrategia" "${PROC_TAM[$p]}"
                if (( ELEGIDO == -1 )); then
                    echo "   ${PROC_NOMBRE[$p]} sigue sin entrar."
                    restantes+=("$p")
                else
                    cargar_proceso "$ELEGIDO" "${PROC_NOMBRE[$p]}" "${PROC_TAM[$p]}"
                    echo "   ${PROC_NOMBRE[$p]} (${PROC_TAM[$p]} KB) cargado tras la compactación."
                fi
            done
            pendientes=("${restantes[@]}")
            calcular_libre
            echo
            echo "   Mapa final:"
            mostrar_mapa
        fi
    fi

    RESUMEN+=("$(printf "%-15s %-10s %-12s %-14s %-12s" "$titulo" "$compacto" "${#pendientes[@]}" "$CANT_HUECOS" "$HUECO_MAYOR KB")")
}

# ---------------------------------------------------------------------
# Programa principal
# ---------------------------------------------------------------------
case ${1:-todos} in
    primer) LISTA=(primer) ;;
    mejor)  LISTA=(mejor) ;;
    peor)   LISTA=(peor) ;;
    todos)  LISTA=(primer mejor peor) ;;
    *) echo "Uso: $0 [primer|mejor|peor]"; exit 1 ;;
esac

declare -A TITULOS=([primer]="PRIMER AJUSTE" [mejor]="MEJOR AJUSTE" [peor]="PEOR AJUSTE")

echo "Procesos a cargar: $(for p in "${!PROC_NOMBRE[@]}"; do printf "%s=%sKB " "${PROC_NOMBRE[$p]}" "${PROC_TAM[$p]}"; done)"
reiniciar_memoria
echo
echo "Estado inicial de la memoria:"
mostrar_mapa

RESUMEN=()
for e in "${LISTA[@]}"; do
    simular "$e" "${TITULOS[$e]}"
done

echo
echo "========================== COMPARACIÓN =========================="
echo "Algoritmo       Compactó   Sin cargar   Huecos final   Hueco mayor final"
echo "-----------------------------------------------------------------"
for linea in "${RESUMEN[@]}"; do echo "$linea"; done
