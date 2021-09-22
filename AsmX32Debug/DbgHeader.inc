
;存放断点信息的结构体
tagBpCommand struct
	m_dwAddr DWORD 0;地址
	m_btOldCode BYTE 0 ;代码
	m_bReset dd 0;是否需要重设的标志 
tagBpCommand Ends

;临时断点
tagTempBp struct
	m_dwAddr DWORD 0;地址
	m_btOldCode BYTE 0 ;代码
tagTempBp Ends

TempBp tagTempBp <0,0>

;硬件断点
tagBhCommand struct 
    m_dwAddr dd 0
    m_dwLen dd 0
    m_btType dd 0
    m_dwReset dd 0
    m_dwDRX dd 0
tagBhCommand Ends


tagModuleInf struct          
	MoudelName DWORD 0                      
tagModuleInf ends

;tagDR7 struct
;        unsigned int L0 : 1;
;        unsigned int G0 : 1;
;        unsigned int L1 : 1;
;        unsigned int G1 : 1;
;        unsigned int L2 : 1;
;        unsigned int G2 : 1;
;        unsigned int L3 : 1;
;        unsigned int G3 : 1;
;        unsigned int LE : 1;
;        unsigned int GE : 1;
;        unsigned int : 1;
;        unsigned int RTM : 1;
;        unsigned int : 1;
;        unsigned int GD : 1;
;        unsigned int : 2;
;        unsigned int RW0 : 2;
;        unsigned int LEN0 : 2;
;        unsigned int RW1 : 2;
;        unsigned int LEN1 : 2;
;        unsigned int RW2 : 2;
;        unsigned int LEN2 : 2;
;        unsigned int RW3 : 2;
;        unsigned int LEN3 : 2;
;tagDR7 Ends

SETDR0  equ  1h
SETDR1  equ  4h
SETDR2  equ  10h
SETDR3  equ  40h

;空闲硬件断点列表
BHDRX STRUCT
    _DR0  dd FALSE
    _DR1  dd FALSE
   _DR2   dd FALSE
   _DR3   dd FALSE
BHDRX ENDS

g_BhIndex         BHDRX<0>                 ;调试寄存器结构体

;EXCEPTION_ACCESS_VIOLATION
;内存断点
;BT_READ dd 0  r 0
;BT_WRITE dd 1 w 1

tagBMCommand struct 
    m_dwAddr dd 0
    m_dwLen dd 0
    m_dwType dd 0;
    m_dwOldProtect dd 0;
    m_bReset dd 0 ;是否需要重设的标志    
tagBMCommand ends


tagEFlags struct 
	eCF dd 1;
	eReserv1 dd 1; //1
	ePF dd 1;
	eReserv2 dd 1; //0
	eAF dd 1;
	eReserv3 dd 1; //0
	eZF dd 1;
	eSF dd 1;
	eTF dd 1;
	eIF dd 1;
	eDF dd 1;
	eOF dd 1;

tagEFlags ends


Node struct
    m_pPre  dd 0
    m_pNext dd 0
    m_pUserData dd 0
Node ends



