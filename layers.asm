﻿text
    .def _c_int00
    .text
    .retain

_c_int00:
; ================= Служебная информация =====================
; A10-A19 включительно регистры для обработки данных, а не сохранения состояний
; в A7 значение НТ
; в A8 указатель стека на начало пакета (а также указатель стека на начало формируемого пакета)
; в A9 лежит идентификатор проца, который отправил пакет (это ARM)
; в A20 начало заполненой части циклического буфера DSP
; в B22 1ая засечка TSC
; В A23 Рег1П (флаг "Это первый пакет данного типа")
; В A24 флаг "является ли этот этап этапом рукопожатий" (-1 --- не рукопожатия. 1 --- рукопожатия)
; В A25 константа 0x000000E0 для выделения типа ПМ
; В A26 РегКолОтвет ("сколько ответов нужно ещё получить на посланный пакет данного типа")
; В A29 период ожидания таймаута
; B1 длина данных из структуры прикладного уровня

;==================================================================
; =================================================================
; Начальные действия DSP
; =================================================================
;==================================================================

;==================================================================
; Инициализировать служебные данные.
;==================================================================
    MVKL 0x0000, A0                     ; Указатель на размер циклического буфера DSP
    MVKLH 0x0C18, A0

    MVKL 0x0004, A1                     ; Указатель на начало заполненной части циклического буфера DSP
    MVKLH 0x0C18, A1

    MVKL 0x0008, A2                     ; Указатель на конец заполненной части буфера DSP
    MVKLH 0x0C18, A2

    MVKL 0x0000, A3                     ; Указатель на размер циклического буфера ARM
    MVKLH 0x0c00, A3

    MVKL 0x0004, A4                     ; Указатель на начало заполненной части буфера ARM
    MVKLH 0x0c00, A4

    MVKL 0x0008, A5                     ; Указатель на конец заполненной части буфера ARM
    MVKLH 0x0c00, A5

    MVKL 0xFFE0, A6                     ; Рзамер буфера DSP
    MVKLH 0x0017, A6

    MVKL 0x0024, A20                    ; Начало заполненной части буфера DSP
    MVKLH 0x0C18, A20

    MVK 0x00000000, A11
    MVKL .S1 0x0040, A10
    MVKLH .S1 0x0184, A10
    STW A11, *A10

    STW A6, *A0                         ; Записать размер буфера DSP в разделяемую память
    STW A20, *A1                        ; Записать начальное значение начала буфера DSP в разделяемую память
    STW A20, *A2                        ; Записать начальное значение конца буфера DSP в разделяемую память

    MVKL 0x000C, B4                     ; Флаг конца инициализации ядра ARM.
    MVKLH 0x0с00, B4    
    MVK 0x00000001, A10                 ; Ожидаемый флаг
wait_initialization:                    ; Ждать, пока другие ядра проведут инициализацию
    LDW     *B4, A11                    ; Флаг инициализации ядра ARM
    nop 4
    CMPEQ   A10, A11, A12
    SUB     .L1 A12, 1, A12
    BPOS    initialization_completed, A12
    nop 5
    B wait_initialization
    nop 5

initialization_completed:

    LDW *A3, A21                        ; Размер буфера ARM
    nop 4

    MVK 0xFFFFFFFF, A24                 ; Для условного перехода в архитектуре DSP
    MVK 0x00000001, A23                 ; Следующий пакет является первым
    MVKL 0x00E0, A25                    ; Константа для выделения типа ПМ
    MVKLH 0x0000, A25

    MVC A0,TSCL                         ; Запустить счётчик тактов
    MVKL 0x0000, A29                    ; Период ожидания таймаута
    MVKLH 0x0010, A29

    B recieve_packages_without_timeout ; Ожидать маркера
    nop 5

;====================================================================================================================================
;====================================================================================================================================
;======================== Прикладной уровень ========================================================================================
;====================================================================================================================================
;====================================================================================================================================
prepare_to_pack:
    MVK 0x00000004, A10                         ; Длина данных
    
    MV B15, A8                                  ; Сохранить указатель стека на начало формируемого пакета                            
    MV  A10, B1                                 ; Сохранить длину данных из структуры в B1 

    MVK 0x00000011, A11                         ; Длина всех заголовков

    ADD A11, A10, A12                           ; 17 байт + "длина данных, полученная из структуры"

    MVK 0x00000002, A13
    STB A13, *-A8[A12]                          ; в стек [17 + "длина данных, полученная из структуры"] 
                                                    ; 1 Байт 02h в качестве "результата выполнения транзакции"

                                                ; в стек [от (17 + ("длина данных, полученная из структуры" - 1)) до 17] включительно

                                                ; Запись данных
    SUB .L1 A12, 1, A12                         ; <- 17 байт + ("длина данных, полученная из структуры" - 1)
    MVK 0x00000044, A13                         ; Записать
    STB A13, *-A8[A12]                          ;   44h

    SUB .L1 A12, 1, A12                         ; <- 17 байт + ("длина данных, полученная из структуры" - 2)
    MVK 0x00000033, A13                         ; Записать
    STB A13, *-A8[A12]                          ;   33h

    SUB .L1 A12, 1, A12                         ; <- 17 байт + ("длина данных, полученная из структуры" - 3)
    MVK 0x00000022, A13                         ; Записать
    STB A13, *-A8[A12]                          ;   22h

    SUB .L1 A12, 1, A12                         ; <- 17 байт + ("длина данных, полученная из структуры" - 4)
    MVK 0x00000011, A13                         ; Записать
    STB A13, *-A8[A12]                          ;   11h

                                                ; в стек [16, 15] 2 байта "длины данных"
                                                    ; сначала младшие байты
                                                    ; потом старшие байты
    MVK 0x00000004, A13
    STB A13, *-A8[16]

    MVK 0x00000000, A13
    STB A13, *-A8[15]
                                                        
                                                 ; в стек [14] 1 Байт "кому" (01h)
    MVK 0x00000001, A13
    STB A13, *-A8[14]

    B  view_handle                               ; передать view_handle
    nop 5

;====================================================================================================================================
;====================================================================================================================================
;========================== Уровень представления ===================================================================================
;====================================================================================================================================
;====================================================================================================================================
view_handle:
                                                ; в стек [13, 12] 2 Байта № алгоритма кодирования                                              
    MVK 0x00000000, A13
    STB A13, *-A8[13]
    STB A13, *-A8[12]

    B from_view_to_transp                       ; Передать Transport_layer
    nop 5

;====================================================================================================================================
;====================================================================================================================================
;========================= Транспортный уровень =====================================================================================
;====================================================================================================================================
;====================================================================================================================================
; Бай типа ПМ:
; 001.. - 1-ый
; 010.. - 2-ой
; 100.. - 3-ий

; ========================================================================
; Получение управления от ур. представления
; ========================================================================
from_view_to_transp:                            ; Отправка "пакета 1"
                            
    MVK 0x00000001, A24                         ; Для отправителя маркера начался этап рукопожатий

    CMPEQ 0x00000000, A23, A18                  ; Если это НЕ первый пакет2 (Рег1П != 1),
    SUB .L1 A18, 1, A18                         ; то
    BPOS it_is_not_first_pack1, A18             ; перейти
    nop 5

    MVK 0x00000000, A23                         ; Следующие пакеты данного типа уже не первые
    MVK 0x00000000, A26                         ; Следующий пакет будет 1ым пакетом, на который нужно ждать ответ

it_is_not_first_pack1:
    ADD A26, 1, A26                             ; Кол-во пакетов, которые нужно ожидать в качестве ответа.
                                                ; Нужно через таймаут снова слать пакеты данного типа
                                                        
    MV  A7, A13                                 ; Получить из A7 значение НТ
    ADD A13, 1, A13                             ; НТ++

    STB A13, *-A8[11]                           ; в стек [11, 10, 9, 8] 4 байта НТ (значение из регистра A7, увеличенное на 1)
    STB A13, *-A8[10]
    STB A13, *-A8[9]
    STB A13, *-A8[8]

    MVK 0x00000021, A13                         ; в стек [7] 1 Байт тип ПМ (0x00000021) --- пакет типа 1
    STB A13, *-A8[7]

    B net_form_pack_1_or_3                      ; Передать на формирование заголовка на сетевом уровне
    nop 5

; ========================================================================
; Получение управления от сетевого ур.
; ========================================================================
from_net_to_transp:
    LDBU    *-A8[7], A11                        ; тип ПМ из стека
    nop 4
    
    AND A25, A11, A11                           ; Выделить ??? *****


    MVK    0x00000020, A18                      ; т.к. 5бит константы только можно в следующую команду
    CMPEQ A18, A11, A17                         ; Если это пакет типа 1
    SUB .L1 A17, 1, A17                         ; то
    BPOS trans_send_package2 , A17              ; передать управление trans_send_package2
    nop 5

    MVK    0x00000040, A18                      ; т.к. 5бит константы только можно в следующую команду
    CMPEQ A18, A11, A17                         ; Если это пакет типа 2
    SUB .L1 A17, 1, A17                         ; то
    BPOS trans_send_package3 , A17              ; передать управление trans_send_package3
    nop 5

    MVK    0x00000080, A18                      ; т.к. 5бит константы только можно в следующую команду
    CMPEQ A18, A11, A17                         ; Если это пакет типа 3
    SUB .L1 A17, 1, A17                         ; то
    BPOS trans_packet3_received , A17           ; передать управление trans_packet3_received
    nop 5


trans_send_package2:                            ; Отправить пакет 2
    MVK 0x00000001, A24                         ; Т.е. для получателя маркера начался этап рукопожатий
    CMPEQ 0x00000000, A23, A18                  ; Если это НЕ первый пакет типа 2 (Рег1П != 1),
    SUB .L1 A18, 1, A18                         ; то
    BPOS it_is_not_first_pack2, A18             ; выбрать эту ветку
    nop 5

    MVK 0x00000000, A23                         ; Следующие пакеты данного типа уже не первые
    MVK 0x00000000, A26                         ; Следующий пакет будет 1ым пакетом, на который нужно ждать ответ

it_is_not_first_pack2:
    ADD A26, 1, A26                             ; РегКолОтвет++

    MVKL 0x0041, A11                            ; Заменить тип ПМ на
    MVKLH 0x0000, A11                           ; 0x000000 41
                                                ; ПМ: 0x000000 41 -- "пакет типа 2"

    STB A11, *-A8[7]                            ; Заменить тип ПМ

    B net_form_pack_2                           ; Передать управление net_form_pack_2
    nop 5

; | длина | Кому = От кого = ПМ и его тип = Контр Сум + НТ + Номер алг кодир-ия | Кому = Длина пакета (меняется в процессе обработки) = Пакет с номером точки входа = Рез вып. транз-ии |
; | 2 | 1 = 1 = 1 = 3 + 4 + 2 | 1 = 2 (1тут1) = столько, сколько в длине пакета (1тут1) = 1 |

trans_send_package3:                            ; Отправить пакет 3
                            
    CMPEQ 0x00000000, A23, A18                  ; Если это НЕ первый пакет2 (Рег1П != 1),
    SUB .L1 A18, 1, A18                         ; то
    BPOS it_is_not_first_pack3, A18             ; выбрать ветку
    nop 5

    MVK 0x00000000, A23
    MVK 0x00000000, A26

it_is_not_first_pack3:
    ADD A26, 1, A26                             ; РегКолОтвет2++

    MVK 0x00000081, A13                         ; в стек [7] 1 Байт тип ПМ (0x00000081) --- пакет типа 1
    STB A13, *-A8[7]

    B net_form_pack_1_or_3                      ; Передать управление net_form_pack_1_or_3
    nop 5

trans_packet3_received:                         ; Обработка полученного пакета 3
    MVK 0xFFFFFFFF, A24                         ; Этап рукопожатий закончен.

    B prepare_to_pack                           ; Передать управление
    nop 5

;====================================================================================================================================
;====================================================================================================================================
;========================= Сетевой уровень ==========================================================================================
;====================================================================================================================================
;====================================================================================================================================

;==================================================================
;==================================================================
; Sender
;==================================================================
;==================================================================
; Отправить так: длина | заголовки | данные

;==================================================================
; Формирование пакета 1 или 3
;==================================================================
net_form_pack_1_or_3:
    MVK     0x00000000, A13                     ; в стек [6, 5, 4] 3Б "контрольной суммы"
    STB     A13, *-A8[6]

    MVK     0x00000000, A14
    STB     A14, *-A8[5]

    MVK     0x00000000, A15   
    STB     A15, *-A8[4]

    MVK     0x000000C1, A16                     ; в стек [3] 1Б "от кого" (C1h)
    STB     A16, *-A8[3]

    MVK     0x00000001, A13                     ; в стек [2] 1Б "кому" (01h)
    STB     A13, *-A8[2]                          
    
    ADD     0x00000010, B1, B14                 ; Прибавить 16 Байт к "длине данных", сохраненной в B1 = "длина пакета"                                                                                 
    MVK     0x00000014, A15                     ; длина пакета 
    MVK     0x00000000, A16
                                                ; записать в стек длину пакета: 
    STB     A15,  *-A8[1]                       ; в стек [1] --- младший байт                  
    STB     A16,  *A8                           ; в стек [0] --- старший байт                                                               

    B check_space                               ; Отправить пакет в разделяемую память
    nop 5
    
;==================================================================
; Формирование пакета 2
;==================================================================
net_form_pack_2:
    STB A9, *-A8[2]                             ; Заменить "кому" в стеке. Смещение с отрицательным знаком.
                                                ; идентификатор ARM: лежит в A9

    MVK 0x000000C1, A10                         ; идентификатор DSP1
    STB A10, *-A8[3]                            ; Заменить "от кого" в стеке на 0x000000C1.

    MVK    0x00000000, A12
    MVK    0x00000000, A13
    MVK    0x00000000, A14

    STB A12, *-A8[4]
    STB A13, *-A8[5]
    STB A14, *-A8[6]

    B check_space                               ; Отправить пакет в разделяемую память
    nop 5

;==================================================================
;==================================================================
; Получатель
;==================================================================
;==================================================================
; | длина | Кому = От кого = ПМ и его тип = Контр Сум + НТ + Номер алг кодир-ия | Кому = Длина пакета (меняется в процессе обработки) = Пакет с номером точки входа = Рез вып. транз-ии |
; | 2 | 1 = 1 = 1 = 3 + 4 + 2 | 1 = 2 (1тут1) = столько, сколько в длине пакета (1тут1) = 1 |

net_handle_pack:
; Прочитать заголовки:
    LDBU *-A8[2], A10                           ; Получить "кому" со стека. Смещение с отрицательным знаком.
    nop 4
    LDBU *-A8[3], A9                            ; Получить "от кого" со стека.
    nop 4                           
    LDBU *-A8[4], A12                           ; Данные
    nop 4                           
    LDBU *-A8[5], A13                           ; контрольной
    nop 4                           
    LDBU *-A8[6], A14                           ; суммы
    nop 4
                                                ; Проверить кс: если не корректна,
                                                ; то удалить пакет из буфера принятых пакетов (стек и разделяемая память).
    MVK 0x00000000, A15
    CMPEQ A15, A14, A15                         ; Сравнить кс
    SUB .L1 A15, 1, A15                         ; Если равны, то нужно 0. Иначе нужно -1
    BPOS new_next_handle, A15                   ; Если равны (A15 = 0), то перейти на обработку пакета
    nop 5

new_next_handle:
                                                ; Сравнить свой номер процессора с номером процессора в заголовке,
                                                ; если не корректны, то удалить пакет из буфера принятых пакетов (стек и разделяемая память).
    MVK 0x000000C1, A17                         ; Идентификатор DSP1
    CMPEQ A17, A10, A16                         ; Сравнить свой идентификатор с идентификатором в пакете
    SUB .L1 A16, 1, A16                         ; Если равны, то нужно 0. Иначе нужно -1
    BPOS from_net_to_transp, A16                ; Если идентификаторы равны (A16 = 0), то перейти на обработку пакета
    nop 5

;====================================================================================================================================
;====================================================================================================================================
;========================= Физический уровень =======================================================================================
;====================================================================================================================================
;====================================================================================================================================
; Чтение/ожидание

;==================================================================
;==================================================================
; Sender. A3 --- maxsize. A4 --- beginning. A5 --- end
;==================================================================
;==================================================================

;==================================================================
; Проверить свободное место в разделяемой памяти
;==================================================================
check_space:
    LDW *A4, A10                                ; Указатель буфера начала ARM
    nop 4
    LDW *A5, A11                                ; Указатель буфера конца ARM
    nop 4

    SUB .L1 A11, A10, A12                       ; A12 = (конец - начало)
    BPOS beg_before_end, A12
    nop 5

                                                ; Если "указаталя конца" стоит ПЕРЕД "указателем начала"
    ADD A21, A12, A12                           ; Значение длины заполненной части буфера --- A12 = размер буфера + (конец - начало)

beg_before_end:                                 ; Если "указатель начала" стоит ПЕРЕД "указаталем конца"
                                                ; продолжить со значением A12 = (конец - начало)
    SUB .L1 A21, A12, A14                       ; Свободное место в буфере --- A14

    SUB .L1 A14, A15, A16                       ; (Размер - длина пакета) --- A16. Проверить размер свободной части
    BPOS get_length_and_send_package, A16       ; Если свободная часть больше записываемого пакета, то перейти к записи
                                                ; Иначе удалить пакет из стека (т.е. продолжить исполнение следующих строк)
    nop 5

;==================================================================
; Очистить стек
;==================================================================
    MV A8, B15                                  ; Очистить стек от пакета, который не удалось передать из-за нехватки места в общей памяти
                                                ; в A8 лежит указатель стека на начало записанного пакета 

    B application_layer_from_phys               ; Перейти на прикладной уровень для повторного формирования 
                                                ; пакета в случае нехватки места в разделяемой памяти ARM
    nop 5

; =================================================================
; Получить длину пакета перед отправкой пакета
; =================================================================
get_length_and_send_package:
    XOR A30, A30, A30
    LDBU *A8, A30                               ; старший байт длины пакета с расширением нулями. 1ый и 2ой байты --- это длина пакета
    nop 4

    XOR A27, A27, A27
    LDBU *-A8[1], A27                           ; младший байт длины пакета
    nop 4

;==================================================================
; Обработать длину, добавить 2 байта к общей длине.
;==================================================================
    ROTL A30, 8h, A30                           ; Сдвинуть биты A30 влево
    nop
    ADD A30, A27, A30                           ; Сложить старший и младший байты

    ADD 2h, A30, A30                            ; +2 байта, т.к. в MSM записывается как пакет, так и длина данного пакета
    MV A30, A31                                 ; ARMу нужно записать длину записанных данных (длина маркера + 2 байта)

    SUB .L1 A30, 1, A30                         ; Уменьшить на 1, т.к. цикл с условием "больше РАВНО нуля"

; Длина пакета в A30 

    MV A8, B5                                   ; Получить указатель на пакет, чтобы отправить пакет в цикле

;==================================================================
; Сохранить данные в разделяемую память.
;==================================================================
send_package:    
    LDBU *B5--, B3                              ; байт со стека
    nop 4
    STB B3, *A10                                ; Записать байт в разделяемую память
    ADD A10, 1, A10                             ; Указатель начала буфера++
    SUB .L1 A30, 1, A30                         ; кол-во оставшихся байтов пакета на стеке--

    BPOS send_package, A30                      ; если байты пакета в стеке не кончились, то цикл (цикл по условию "больше РАВНО нулю")
    nop 5

                                                ; Ветка, когда все байты из стека записаны
    ADD A31, A11, A11                           ; Увеличить указатель конца буфера ARM на длину записанных данных
    STW A11, *A5                                ; Записать обновлённый указатель конца буфера ARM

;==================================================================
; Очистить стек.
;==================================================================
    MV A8, B15                                  ; Очистить стек от пакета, который передан в общую память

;==================================================================
; Перейти на этап рукопожатий.
;==================================================================
    MVC TSCL, B22                               ; В B22 сделать засечку из TSC для начала отсчёта таймаута, т.к. пакет в памяти уже записан

    B recieve_packages                          ; передать управление этапу рукопожатий
    nop 5

;==================================================================
;==================================================================
; Получатель
;==================================================================
;==================================================================

;==================================================================
; Проверить необходимость таймаутов и контролировать их при необходимости
;==================================================================
recieve_packages:
    BPOS check_timeout, A24                     ; Проверить флаг A24: является ли это этапом рукопожатий
    nop 5                                       ; Если A24 = -1, то не является, поэтому
    B recieve_packages_without_timeout          ; Передать управление recieve_packages_without_timeout
                                                ; Иначе продолжать выполнение с проверкой таймаута
    nop 5
check_timeout:
    MVC TSCL, B10                               ; Счётчик тактов
    SUB .L2 B22, B10, B10
    CMPGT B10, A29, B10                         ; Вышел ли таймаут
    SUB .L2 B10, 1, B10
    BPOS trans_send_package2, B10               ; Если = 0, то вышел => trans_send_package2
    nop 5


;==================================================================
; Проверять буфер на наличие пакетов.
;==================================================================
recieve_packages_without_timeout:
                                                ; В A20 указатель на начало буфера DSP
                                                ; Который я узнаю после конца части отправления пакета и конца получения пакета

    LDW *A2, A10                                ; Указатель конца буфера DSP
    nop 4

    SUB .L1 A10, A20, A11                       ; Указатель на конец вычитается из начала. A10 - A20 -> A11
    CMPEQ 0h, A11, A12                          ; Равна ли длина заполненной часть нулю. Если равна 1 -> A12, иначе 0 -> A12
    SUB .L1 A12, 1, A12                         ; Вычесть 1 из A12, чтобы понять: делать или не делать условный переход далее
    BPOS recieve_packages, A12                  ; Если в А12 0 (значит длина заполненного буфера ноль), 
                                                ; то сделать переход на очередное чтение разделяемой памяти
                                                ; Иначе (она равна -1, и это значит, что длина заполненного буфера не ноль) выполнить следующую инструкцию
    nop 5

;==================================================================
; Очистить стек.
;==================================================================
    MV B15, A8                                  ; Сохранить указатель стека на начало считываемого пакета

;==================================================================
; Читать, начиная с длины пакета (длина всего маркера = (2 Б + длина пакета Б))
;==================================================================    
    XOR A30, A30, A30
    LDBU *A20, A30                              ; 1ый байт длины пакета с расширением нулями. 1ый и 2ой байты --- это длина пакета
    nop 4
    STB A30, *B15--                             ; Загрузка на стек 1го байта длины пакета

    ADD A20, 1, A20                             ; Указатель начала DSP++

    XOR A27, A27, A27
    LDBU *A20, A27                              ; 2ой байт длины пакета
    nop 4
    STB A27, *B15--

    ADD A20, 1, A20                             ; Указатель начала DSP++

;==================================================================
; Обработать длину.
;==================================================================
    ROTL A30, 8h, A30                           ; Сдвинуть A30 влево
    nop
    ADD A30, A27, A30                           ; Сложить старшие и младшие байты
                                                ; Длина пакета в A30
;==================================================================
; Прочитать пакет
;==================================================================
read_package:
    LDBU *A20, A31                              ; 1 байт из буфера.
    nop 4
    STB A31, *B15--                             ; Пуш на стек 1 байт. Стек растёт декрементом.
    ADD A20, 1, A20                             ; Указатель начала++
    SUB .L1 A30, 1, A30                         ; Вычесть 1 из длины пакета, т.к. эти байты уже прочитаны
    CMPGT A30, 0, A28                           ; Если длина непрочитанных данных больше нуля, 
                                                ; то записать 1 в A28, иначе записать 0 в A28
    SUB .L1 A28, 1, A28                         ; Вычесть 1 из A28, чтобы понять: делать или не делать условный переход далее
    BPOS read_package, A28                      ; Перейти к read_package, если 0 (если длина данных > 0),
                                                ; выполнить следующую инструкцию, если -1 (если длина даных = 0)
    nop 5

;==================================================================
; Сдвинуть указатель на начало буфера DSP
;==================================================================
                                                ; В A20 содержится указатель на начало заполненной непрочитанной части буфера
    STW A20, *A1                                ; Сдвинуть буфер начала заполненной части кольцевого буфера

;==================================================================
; Проверка на рукопожатия
;==================================================================
    BPOS timeout_nadle, A24                     ; Если A24 = 1, то исполнять далее ветку обработки таймаутов
    nop 5                                       ; иначе обрабатывать самый первый полученный пакет
    B net_handle_pack                           ; т.е. перейти к метке "net_handle_pack"
    nop 5

;==================================================================
; Обработка ожидания пакетов по таймауту
;==================================================================
timeout_nadle:
    SUB .L1 A26, 1, A26                         ; РегКолОтвет--

    CMPGT A26, 0, A10                           ; кол-во не полученных пакетов данного типа > 0?
    SUB .L1 A10, 1, A10
    BPOS recieve_packages, A10                  ; Если > 0, то recieve_packages
    nop 5

    MVK 0x00000001, A23 ; Рег1П <- 1            ; Когда все пакеты получены, выставлять флаг того, что следующий тип пакета
                                                ; будет первым в передаче данного типа пакетов.

    B net_handle_pack ; Передача управления сетевому уровню получателя
    nop 5

application_layer_from_phys:                     ; Метка в случае нехватки места под пакет в буфере принятых пакетов у другого процессора
    B application_layer_from_phys
    nop 5

    nop
.END