.386
.model flat,stdcall
option casemap:none


   include windows.inc
   include msvcrt.inc
   include masm32.inc
   include user32.inc
   include kernel32.inc
   include Decode2Asm.inc
   include psapi.inc
   
   includelib user32.lib
   includelib kernel32.lib
   includelib masm32.lib
   includelib msvcrt.lib
   
InvokeTRUE Macro
    mov eax,1
    ret
endm

InvokeFALSE Macro
    mov eax,0
    ret
endm

_IOBUFF STRUCT 
_ptr  dd ?
_cnt  dd ?
_base dd ?
_flag dd ?
_file dd ?
_charbuf dd ?
_bufsiz  dd ?
_tmpfname dd ?
_IOBUFF ENDS

extern _iob:_IOBUFF

;函数声明
InputCommand proto:DWORD
InsertLst proto  pHead:ptr Node, pUserData:DWORD
DeleteUseIdxlst  proto  pHead:ptr Node, nIdx:DWORD
Deletelst proto  pHead:ptr Node, pNodeToDel:ptr Node
OnBPCommand proto :DWORD
SaveTraceToFile proto
OnTCommand proto
OnRCommand proto
OnAccessViolation proto
WritePEFile proto pBuff:dword,dwSize:dword
GetPeInf proto
.const
    g_szBP db "BP",0ah,0
    g_szBL db "BL",0ah,0
    g_szBC db "BC",0ah,0
    
    g_DebugUIInput db "请输入执行命令:",0ah,0
    g_DebugUIDB db "debug   调试（debug xx.exe）",0ah,0
    g_DebugUIH db "h 查看帮助",0ah,0
    g_DebugUIQ db "q 退出",0ah,0
    g_DebugCmdError db "输入错误！请输入正确的命令(q:quit / debug xxx.exe): ",0ah,0
    g_DebugCmdInputError db "没有找到调试的exe程序路径！请输入正确的命令(q:quit / debug xxx.exe): ",0ah,0
    
    g_crlf  db  0ah,0  
                    
    g_szTextProcExe db  'calc.exe', 0
    
    
    g_strStartDebugError db "建立调试会话失败",0ah,0
	g_strInputError db "指令输入有误，请重新输入!",0ah,0
	g_strReadError db "内存读取失败",0ah,0
	g_strWriteError db "内存写入失败",0ah,0
	g_strCreateFileError db "文件创建失败",0ah,0
	g_szPrintRegError db "寄存器信息读取失败",0ah,0
	g_szPrintSetRegError db "寄存器信息设置失败",0ah,0
    g_szSetTError db "单步执行失败",0ah,0
    g_szVPError db "内存属性修改失败",0ah,0
    g_szScriptError	db "指令输出错误，脚本功能SS:保存,SR:读取",0ah,0 
    g_SzScripNull db "，保存失败,当前未输入过指令",0ah,0
	g_Call db "call",0 
	
	g_szHelp1	db "********************X32Dbg帮助文档*******************", 0ah, 0
	g_szHelp2	db "												", 0ah, 0
	g_szHelp3	db "    1. T 步入 P 步过 G/G+ADDR 执行							", 0ah, 0
	g_szHelp4	db "    2. U/U+ADDR 显示反汇编								", 0ah, 0
	g_szHelp5	db "    3. D/D+ADDR 查看内存								", 0ah, 0
	g_szHelp6	db "    4. E+ADDR+CODE 修改内存								", 0ah, 0
	g_szHelp7	db "    5. R 查看寄存器										", 0ah, 0
	g_szHelp8	db "    6. BP+ADDRIN3 断点 BL 查看 BC+n清除						", 0ah, 0
	g_szHelp9	db "    7. R/R+ADDR 显示寄存器信息							", 0ah, 0
	g_szHelp10	db "    8. bh+Addr+1/2/4+a/e/w硬件断点 BHL查看 BHC+n删除 ", 0ah, 0
	g_szHelp11	db "    9. bm+addr+len+r/w内存断点 BML查看 BPC+1/2/3删除		", 0ah, 0
	g_szHelp12	db "    10. Ret 执行到返回									", 0ah, 0
	g_szHelp13	db "    11. TRACE+P/T+ADDR 过/不过CALL记录指令							", 0ah, 0
	g_szHelp14	db "    12. SS 脚本报存 SR 脚本读取							", 0ah, 0
	g_szHelp15	db "    13. O 脱壳Dump内存								", 0ah, 0
	g_szHelp16	db "    14. L 查看当前进程使用的模块DLL	 ", 0ah, 0
	g_szHelp17	db "    15. Q 退出									", 0ah, 0
	g_szHelp18	db "    16. H 查看帮助文档				", 0ah, 0
	g_szHelp19	db "                                                ", 0ah, 0
	g_szHelp20  db "*****************************************************", 0ah, 0
.data
    g_szProcExe db 32 dup(0)
    g_szPrintText db "Hello World!",0ah,0
	g_szScanFomat db "%255[^" ,0Ah, "]",0
	g_szDumpFile db "Dump.exe",0
	 
	g_szInputInf db "[cmd]:",0
	g_szWCharPrintInf db "[DLL]:%ws",0ah,0
	g_szCharPrintInf db "[DLL]:%s",0dh,0
	g_szPrintAsm db "[Asm]:%p %s",0ah,0
	
	g_szWsd db "%d",0ah,0
	g_szWss db "%s",0ah,0
		
	;--------脚本-----
	g_szScript db "[Script]:%s",0ah,0
	g_szScriptFile db "Script.txt",0
	g_szScriptBuffer db 3000 dup(?) ;用来存放所有指令
	g_szScriptRead db 1000 dup(0)
	
	g_nNumberofCmd dd 0
	g_szWsCmd db "%s",0ah,0
	g_szSpcae dd 0ah,0
    g_scriptCmd db 32 dup(0)    
	m_bIsReadScript dd 0
	m_bIsScriptFirst dd 0
	g_szCmdTemp db 1000 dup(0)
	g_CmdLen dd 0
    g_Cmdptr dd 0	
    g_nIndex dd 0
    ;--------List---
    g_szBPPrint db "断点列表:",0ah,0
    g_szBCError db "不存在该断点",0ah,0
    g_szBPIn db "该断点已经存在",0ah,0 
    g_BpLst dd NULL
	g_BpTempLst dd NULL
	g_szShowBPCode db "%02X",0ah,0
    g_szShowBPLst db "%d. %08x ",0ah,0
    g_nScIndex dd 0
    g_szBpLen db "%d",0
 	;------显示寄存器----
	g_szTextReg db "ZF=%02X",0ah,0
	g_szPrintReg_1 db "EAX = %08X  EBX = %08X  ECX = %08X  EDX = %08X  ESI = %08X  EDI = %08X",0ah,0
	g_szPrintSign db "EIP = %08X  ESP = %08X  EBP = %08X  CF  PF  AF  ZF  SF  TF  IF  DF  OF",0ah,0
	g_szPrintSignInfo db "                                                %02X  %02X  %02X  %02X  %02X  %02X  %02X  %02X  %02X",0ah,0
	g_szPrintReg_2 db "CS = %04X  SS = %04X  DS = %04X  ES = %04X  FS = %04X   GS = %04X",0ah,0
	;-----显示内存------
	g_szPrintHex8 db "%08X ",0
	g_szPrintHex2 db "%02X ",0
	g_szPrintChar db "%c",0
	g_szPrintSpace db "   ",0
	g_szPrintNextLen db  0ah,0
	g_szPrintPoint db ".",0
	;------修改内存----
	g_szSetEError db "E指令输入错误正确格式 E+addr+内容",0ah,0
	g_SetCode db 32 dup(0)
	g_AsciiCode db 32 dup(0)
	
	;-----trace-----
	g_szTraceFile db "trace.txt",0
	g_szIsTraceSave db "是否记录脚本内容? S-保存 任意键-不保存",0ah,0
	g_szTaceSaveSuccess db "脚本内容保存成功",0ah,0
    g_szTrace db "脚本 trace+t/p+Addr t遇CALL进入，p遇CALL不入",0ah,0
    m_bTraceCmd dd 0;//Trace命令标志
	m_bTraceType dd 0;Trace 类型0->t，1->P
	g_dwEndTraceAddr dd 0;Trace结束地址
	g_szWsAsm db "%p %s",0ah,0
	;-------bh硬件断点------
	g_szSetBhError db "硬件断点设置失败，格式:BH+Addr+1/2/4+e执行/a写入/w读写",0ah,0
	g_szSetBhNumbError db "硬件断点设置失败，最多存在4个硬件断点",0ah,0
	g_szShowFmtBH db "硬件断点设置成功!断点地址:%08x 断点长度:%d 断点类型:",0
	g_TestBH db "BH",0ah,0	
	g_TestBHL db "BHL",0ah,0	
	g_TestBHC db "BHC",0ah,0
	g_BhLst dd NULL
	g_szbhType0 db "执行",0ah,0
	g_szbhType1 db "写入",0ah,0
	g_szbhType3 db "读写",0ah,0
	m_bBhSingStep dd 0; //是否是硬件断点拿到单步标志
	g_nIndexBh dd 0 ;硬件断点命中的索引
	   
	;-------bm内存断点------
	g_szSetBMError  db "内存断点设置失败，格式: BM+Addr+len+r/w",0ah,0
    g_szShowFmtBM db"内存断点设置成功! 断点地址:%08x 断点长度:%d 断点类型:%d 内存:%08x 是否重设:%d",0ah,0
    g_TestBM db "BM",0ah,0	
	g_TestBML db "BML",0ah,0	
	g_TestBMC db "BMC",0ah,0
    g_BMLst dd NULL
    g_BMSetFalied db "内存断点失败，请检查内存是否存在",0ah,0 
    g_BMSetAlive db "内存断点设置失败，内存断点已经存在",0ah,0
    g_BMSetOverLapping db "内存断点设置失败，断点交叉",0ah,0
    
    g_dwTempAddr dd 0 ;保存临时地址
    
    ;-----标志---------
	m_bIsSystemBp BOOL TRUE; //是否是系统断点标志
	m_bSingStepCmd dd 0;//单步标志
	m_bTCommand dd 0;//T命令标志
    m_bInputCommand dd 1;输入命令标志
    m_hTraceFile HANDLE 0
    m_hScriptFile HANDLE 0
    m_SciptFile HANDLE 0
    m_hProc HANDLE 0
    m_hThread HANDLE 0
    m_de DEBUG_EVENT <>
       
    ;-----PE 信息-----
      
    g_pImgBase dd 0
    g_dwModule dd 0 
    g_dwSecHdrAddr dd 0
    g_pImgDosHdr IMAGE_DOS_HEADER <>
    g_pImgNtHdr IMAGE_NT_HEADERS32 <>
    g_pImgFileHdr IMAGE_FILE_HEADER <>
    g_pImgOptionalHdr IMAGE_OPTIONAL_HEADER <>
    g_pImgSecHdr IMAGE_SECTION_HEADER <> 
    
    ;------模块DLL-------
    g_DllLst dd NULL
    g_szShowDLL db "当前模块列表:",0ah,0
    g_szGetDProError db "进程快照获取失败!",0ah,0
    g_szGetDllError db "模块快照获取失败!",0ah,0
    g_szDllPath db 512 dup(0)
    g_DllptrIndex dd 0;
    