include AsmX32Debug.Inc
include DbgHeader.Inc
include link.inc

.code

;---------------链表增加数据-------
InsertLst proc uses ecx edx ebx esi edi pHead:ptr Node, pUserData:DWORD
    LOCAL @pNewNode:ptr Node
    
    ;申请新节点   
    invoke crt_malloc, sizeof Node
    .if eax == NULL
        ret
    .endif 
    mov @pNewNode, eax
    
    ;赋值, 新节点入链表,新节点为新的头结点
    mov esi, @pNewNode
    assume esi:ptr Node
    
    mov edi, pHead
    assume edi:ptr Node
    
    mov [esi].m_pPre, NULL
    mov [esi].m_pNext, edi
    mov eax, pUserData
    mov [esi].m_pUserData, eax
    
    .if edi != NULL
        mov eax, @pNewNode
        mov [edi].m_pPre, eax        
    .endif
    assume esi:nothing
    assume edi:nothing
    
    mov eax, @pNewNode
    ret

InsertLst endp
;---------------链表删除数据---
DeleteLst proc uses ecx edx ebx esi edi  pHead:ptr Node, pNodeToDel:ptr Node

    mov esi, pHead
    assume esi:ptr Node
    
    mov edi, pNodeToDel
    assume edi:ptr Node
    
    ;与头结点交换数据
    mov eax, [esi].m_pUserData
    mov [edi].m_pUserData, eax
    
    assume edi:nothing
    
    ;删除头结点
    mov edi, [esi].m_pNext
    assume edi:ptr Node
    
    .if edi!=0
        mov [edi].m_pPre, NULL    
    .endif
     
    assume edi: nothing
    
    invoke crt_free, esi
    
    ;返回新的头结点
    mov eax, edi
    ret

DeleteLst endp
;--------------链表按序号删除-----
DeleteUseIdxLst proc uses ecx edx ebx esi edi pHead:ptr Node, nIdx:DWORD
    LOCAL @dwIndex:DWORD
    mov @dwIndex,0
    
;    mov esi, pHead
;    assume esi:ptr Node
;    
;    .while esi != NULL
;        inc @dwIndex
;        mov esi, [esi].m_pNext
;    .endw
    
;    assume esi:nothing
    ;invoke crt_printf,offset g_szBpLen,@dwIndex
    
    ;mov ebx,@dwIndex
    mov esi, pHead
    assume esi:ptr Node
    ;.if  nIdx<ebx
        
        mov ecx,0
        .while ecx < nIdx
            mov esi, [esi].m_pNext    
            inc ecx    
        .endw  

        invoke DeleteLst, pHead, esi
        assume esi:nothing
        ret
    ;.else
        ;assume esi:nothing
        ;invoke crt_printf,offset g_szBCError
        ;ret
    ;.endif
    

    ret 
    
DeleteUseIdxLst endp
;-----------------设置INT3断点--------------------
SetBp Proc uses ecx edx ebx esi edi dwAddr:DWORD,btOldCode:BYTE
;	BYTE btCode = 0xcc;
;	DWORD dwOldProc = 0;
;	VirtualProtectEx(m_hProc, (LPVOID)dwAddr, sizeof(btCode), PAGE_READWRITE, &dwOldProc);
;	DWORD dwBytesToRead = 0;
;
;	//获取该内存处内存信息到dwAddr和btOldCode
;	BOOL bRet = ReadProcessMemory(m_hProc, (LPVOID)dwAddr, btOldCode, sizeof(BYTE), &dwBytesToRead);
;	DWORD dwBytesToWrite = 0;
;	bRet = WriteProcessMemory(m_hProc, (LPVOID)dwAddr, &btCode, sizeof(btCode), &dwBytesToWrite);
;	VirtualProtectEx(m_hProc, (LPVOID)dwAddr, sizeof(btCode), dwOldProc, &dwOldProc);
    LOCAL @btCode:BYTE
    LOCAL @dwOldProc:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @dwBytesToWrite:DWORD
    
    mov @btCode,0CCh
    mov @dwOldProc,0
   
    
    invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,PAGE_EXECUTE,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
     mov @dwBytesToRead,0
     invoke ReadProcessMemory,m_hProc,dwAddr,addr btOldCode,sizeof btOldCode,addr @dwBytesToRead
     
     .if eax==0
        invoke crt_printf,offset g_strReadError
    .endif
    
     mov @dwBytesToWrite,0
     invoke WriteProcessMemory,m_hProc,dwAddr,addr @btCode,sizeof @btCode,addr @dwBytesToWrite
    .if eax==0
        invoke crt_printf,offset g_strWriteError 
    .endif
    
     invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,@dwOldProc,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
    mov al,btOldCode
    ret
SetBp endp
;-----------------设置硬件断点--------------------
SetBh Proc uses ecx edx ebx esi edi dwAddr:DWORD,dwLen:DWORD,dwHpType
    LOCAL @bIsBhFlag:DWORD 
    LOCAL @index:DWORD
    LOCAL @dwDR7:dword
    LOCAL @ctx:CONTEXT   
    mov @index,0
    
    mov esi, g_BhLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBhCommand
        
        inc @index
        assume eax:nothing       
        mov esi, [esi].m_pNext
    .endw
    
    .if @index>4
        mov eax,0
        ret
    .endif
      
    invoke RtlZeroMemory,addr @ctx ,sizeof @ctx
    mov @ctx.ContextFlags,CONTEXT_ALL
    invoke GetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintRegError	
        ret
    .endif    
       ;mov eax,@ctx.iDr7
    .if @index==0
        ;使用DR0寄存器
         mov eax,dwAddr
         mov @ctx.iDr0 ,eax
         OR @ctx.iDr7,SETDR0

         shl dwLen,18            ;设置断点长度
         mov eax,dwLen
         OR @ctx.iDr7 ,eax          ;设置断点类型 
         mov eax ,dwHpType
         shl eax,16
         OR  @ctx.iDr7 ,eax
        mov g_BhIndex._DR0 ,TRUE
    .elseif @index==1
        ;使用DR1寄存器
         mov eax,dwAddr
         mov @ctx.iDr1 ,eax
         OR @ctx.iDr7 , SETDR1
         ;设置断点长度
         shl dwLen,22
         mov eax,dwLen
         OR @ctx.iDr7 ,eax
         ;设置断点类型
         mov eax ,dwHpType
         shl eax,20
         OR  @ctx.iDr7 ,eax
         mov g_BhIndex._DR1 ,TRUE
    .elseif @index==2
        ;使用DR2寄存器
         mov eax,dwAddr
         mov @ctx.iDr2 ,eax
         OR @ctx.iDr7 , SETDR2
         ;设置断点长度
         shl dwLen,26
         mov eax,dwLen
         OR @ctx.iDr7 ,eax
         ;设置断点类型
         mov eax ,dwHpType
         shl eax,24
         OR  @ctx.iDr7 ,eax

        mov g_BhIndex._DR2 ,TRUE           
    .elseif @index==3
        ;使用DR3寄存器
                 mov eax,dwAddr
         mov @ctx.iDr3 ,eax
         OR @ctx.iDr7 , SETDR3
         shl dwLen,30
         mov eax,dwLen
         OR @ctx.iDr7 ,eax
         mov eax ,dwHpType
         shl eax,28
         OR  @ctx.iDr7 ,eax
         mov g_BhIndex._DR3 ,TRUE
    .else
        mov eax,0
        ret      
    .endif
    
     invoke SetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintRegError	
        ret
    .endif  
    
    mov eax,1 
    ret
SetBh Endp
;-----------------StartDebug--------------------
StartDebug Proc uses ecx edx ebx esi edi strProcExe:DWORD

;			//1）建立调试会话
;			STARTUPINFO si = {};
;			PROCESS_INFORMATION pi = {};
;			si.cb = sizeof(si);
;			BOOL bRet = CreateProcess(NULL,(LPSTR)strproc.c_str(),NULL,NULL,FALSE,
;			DEBUG_ONLY_THIS_PROCESS | CREATE_NEW_CONSOLE,NULL,NULL,&si,&pi);
;			if (bRet)
;			{
;				CloseHandle(pi.hThread);
;				m_hProc = pi.hProcess;
;				return TRUE;
;			}
;			else if(!bRet)
;			{
;				cout << "没有找到调试的exe程序路径！请输入正确的命令(q:quit / debug xxx.exe): " << endl;
;			}
;-------------------------------------------------------
    LOCAL @si:STARTUPINFO
    LOCAL @pi:PROCESS_INFORMATION
    LOCAL @Exe[32]:BYTE
    invoke RtlZeroMemory,addr @si,sizeof @si
    invoke RtlZeroMemory,addr @pi,sizeof @pi
    

    mov @si.cb,sizeof @si
    invoke CreateProcessA,NULL,strProcExe,NULL,NULL,FALSE,DEBUG_ONLY_THIS_PROCESS,NULL,NULL,addr @si,addr @pi
    .if eax==0
        InvokeFALSE
    .endif
    
    push @pi.hProcess
    pop m_hProc
    
    invoke CloseHandle,@pi.hThread
    InvokeTRUE
StartDebug endp
;-----------------设置单步-1标志----------------
DecEip Proc uses ecx edx ebx esi edi 
;	CONTEXT ctx;
;	ctx.ContextFlags = CONTEXT_ALL;
;	GetThreadContext(m_hThread, &ctx);
;	ctx.Eip -= 1;
;	SetThreadContext(m_hThread, &ctx);
    LOCAL @ctx:CONTEXT
    invoke RtlZeroMemory,addr @ctx ,sizeof @ctx
    mov @ctx.ContextFlags,CONTEXT_ALL
    invoke GetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintRegError	
        ret
    .endif
    mov eax,@ctx.regEip
    SUB eax,1  
    mov @ctx.regEip,eax
    invoke SetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintSetRegError	
        ret
    .endif  
    
    ret
DecEip endp
;-----------------设置单步标志--------------
SetTFAndDecEip Proc uses ecx edx ebx esi edi dwDecVal:DWORD
;	CONTEXT ctx;
;	ctx.ContextFlags = CONTEXT_ALL;
;	GetThreadContext(m_hThread, &ctx);
;	ctx.Eip -= dwDecVal;
;	ctx.EFlags |= 0x100;  //  单步标志位
;	SetThreadContext(m_hThread, &ctx);
    LOCAL @ctx:CONTEXT
    
    invoke RtlZeroMemory,addr @ctx ,sizeof @ctx
    mov @ctx.ContextFlags,CONTEXT_ALL
    invoke GetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintRegError	
        ret
    .endif
    mov eax,@ctx.regEip
    SUB eax,dwDecVal   
    mov @ctx.regEip,eax
    
    mov eax,@ctx.regFlag
    OR eax,256
    mov @ctx.regFlag,eax
    invoke SetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintSetRegError	
        ret
    .endif  
    
    ret
SetTFAndDecEip endp
;-----------------显示/输出反汇编内容-----------------------------
ShowAsmInfo Proc uses ecx edx ebx esi edi
;	LPVOID pAddr = m_de.u.Exception.ExceptionRecord.ExceptionAddress;
;
;	BYTE aryCode[16] = {};
;	DWORD dwBytesToRead = 0;
;	ReadProcessMemory(m_hProc, pAddr, aryCode, sizeof(aryCode), &dwBytesToRead);
;	char szAsm[MAXBYTE] = {};
;	UINT nAsmLen = 0;
;	char strOpcode[MAXBYTE] = {};      // 解析机器码信息
;	Decode2AsmOpcode(aryCode, szAsm, strOpcode, &nAsmLen, (UINT)pAddr);
;
;	printf("[INF]: %p %s \r\n", pAddr, szAsm);
    LOCAL @pAddr:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @nAsmLen:DWORD
    LOCAL @aryCode[16]:DWORD
    LOCAL @szAsm[MAXBYTE]:DWORD
    LOCAL @strOpcode[MAXBYTE]:DWORD   
    LOCAL @szBuffer[MAXBYTE]:DWORD
    LOCAL @bytesWritten:DWORD
    LOCAL @dwLen:DWORD
    ;初始化
    mov @dwLen,0
    mov @pAddr,0
    mov @dwBytesToRead,0
    mov @nAsmLen,0
    mov @bytesWritten,0
    invoke RtlZeroMemory,addr @aryCode,32
    invoke RtlZeroMemory,addr @aryCode,16
    invoke RtlZeroMemory,addr @szAsm,sizeof @szAsm
    invoke RtlZeroMemory,addr @strOpcode,sizeof @strOpcode
    invoke RtlZeroMemory,addr @szBuffer,32
    
    invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    invoke ReadProcessMemory,m_hProc,@pAddr,addr @aryCode,sizeof @aryCode,addr @dwBytesToRead
    
    .if eax==0
        ret
    .endif
    
    invoke Decode2AsmOpcode,addr @aryCode,addr @szAsm,addr @strOpcode,addr @nAsmLen,@pAddr
    
    .if m_bTraceCmd==1
        invoke wsprintf,addr @szBuffer,offset g_szWsAsm,@pAddr,addr @szAsm
        ;invoke crt_printf,addr @szBuffer
        invoke SetFilePointer,m_hTraceFile,0,NULL,FILE_END
        
        invoke crt_strlen,addr @szBuffer
        mov @dwLen,eax
        
        invoke WriteFile,m_hTraceFile,addr @szBuffer,@dwLen,@bytesWritten,NULL
        
        .if eax ==0
            invoke crt_printf,offset g_strWriteError
        .endif
        
    .endif
     
    invoke crt_printf, offset g_szPrintAsm, @pAddr, addr @szAsm	
    ret
    
ShowAsmInfo endp
;-----------------BP+Addr 设置置INT3断点-------------------
OnBpCommand proc uses ecx edx ebx esi edi dwAddr:DWORD
    LOCAL @index:DWORD
    LOCAL @btOldCode:BYTE
    
;	//设置断点

    ;判断此断点是否存在       
    mov esi, g_BpLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBpCommand
        
        mov ebx,[eax].m_dwAddr
        .if ebx==dwAddr
            invoke crt_printf,offset g_szBPIn
            ret
        .endif      
        assume eax:nothing     
        mov esi, [esi].m_pNext
    .endw
     
    ;设置断点
    invoke SetBp,dwAddr,@btOldCode    
    mov @btOldCode,al
    
    ;invoke crt_printf,offset g_szShowBPCode,@btOldCode
    
    .if eax
        ;将断点信息插入链表
        invoke crt_malloc, sizeof tagBpCommand 
        assume eax:ptr tagBpCommand
        mov ebx,dwAddr
        mov [eax].m_dwAddr,ebx
        mov ebx,0
        mov bl,@btOldCode
        mov [eax].m_btOldCode,bl
        assume eax:nothing
    
        invoke InsertLst,g_BpLst,eax
        mov g_BpLst, eax  
    .endif
    
        ret
OnBpCommand endp
;-----------------BL 显示所有INT3断点---------------------------
OnBLCommand proc uses ecx edx ebx esi edi 
    LOCAL @index:DWORD
    

    invoke crt_printf, offset g_szBPPrint
    
    mov esi, g_BpLst
    assume esi:ptr Node
    
    mov @index,0
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBpCommand
        
        invoke crt_printf,offset g_szShowBPLst,@index,[eax].m_dwAddr
        inc @index
        assume eax:nothing
        
        mov esi, [esi].m_pNext
    .endw
    
    ret
OnBLCommand endp
;-----------------BC+dwNum 删除INT3断点----------------------------
OnBCCommand proc uses ecx edx ebx esi edi dwNum:DWORD
    
    invoke DeleteUseIdxLst, g_BpLst, dwNum
    mov g_BpLst, eax
    
    ret
OnBCCommand endp
;-----------------BM 内存断点-------------------
OnBMCommand proc uses ecx edx ebx esi edi dwAddr:DWORD,dwLen:DWORD,btHpType:DWORD
    LOCAL @HitBhAddr:DWORD
    LOCAL @HitBhLen:DWORD 
    LOCAL @bRet:BOOL
    LOCAL @dwOldProtect:DWORD
    LOCAL @bReset :DWORD
    
    mov @dwOldProtect,0
    mov @bReset,0
    mov @bRet,FALSE
    mov @HitBhAddr,0
    mov @HitBhLen,0
     ;判断内存断点是否存在(是否设置/类型是否一样/是否交叉)
       
    mov esi, g_BMLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBMCommand
        
        mov ebx,[eax].m_dwAddr
        mov @HitBhAddr,ebx
        mov ebx,[eax].m_dwLen
        mov @HitBhLen,ebx
        
        assume eax:nothing  
          
        ;是否存在
        mov ebx,dwAddr
        .if @HitBhAddr==ebx
            invoke crt_printf,offset g_BMSetAlive
            ret
        .endif   
        ;是否交叉
        ;if (cmdExt.m_dwAddr <= bmCmd.m_dwAddr &&bmCmd.m_dwAddr <= cmdExt.m_dwAddr + cmdExt.m_dwLen)
        mov eax,@HitBhAddr
        ADD eax,@HitBhLen       
        mov ebx,dwAddr    
        .if @HitBhAddr<=ebx&& dwAddr<=eax
            invoke crt_printf,offset g_BMSetOverLapping
            ret
        .endif
        ;if (bmCmd.m_dwAddr <= cmdExt.m_dwAddr &&cmdExt.m_dwAddr <= bmCmd.m_dwAddr + bmCmd.m_dwLen)
        mov eax,dwAddr
        Add eax,dwLen
        mov ebx,@HitBhAddr
        .if dwAddr<=ebx&& @HitBhAddr<=eax
            invoke crt_printf,offset g_BMSetOverLapping
            ret
        .endif
        mov esi, [esi].m_pNext
    .endw
    
    ;修改内存属性
    ;BOOL bRet = VirtualProtectEx(m_hProc,(LPVOID)bmCmd.m_dwAddr,bmCmd.m_dwLen,PAGE_NOACCESS,&bmCmd.m_dwOldProtect);
    invoke VirtualProtectEx,m_hProc,dwAddr,dwLen,PAGE_NOACCESS,addr @dwOldProtect   
    mov @bRet,eax
    .if @bRet==FALSE
       invoke crt_printf,offset g_BMSetFalied 
       ret
    .endif
    ;保存断点信息到链表
    invoke crt_malloc, sizeof tagBMCommand 
    assume eax:ptr tagBMCommand
    mov ebx,dwAddr
    mov [eax].m_dwAddr,ebx
    mov ebx,dwLen
    mov [eax].m_dwLen,ebx
    mov ebx,btHpType
    mov [eax].m_dwType,ebx
    mov ebx,@dwOldProtect  
    mov [eax].m_dwOldProtect,ebx
    mov ebx,@bReset
    mov [eax].m_bReset,ebx
    
    assume eax:nothing
    
    invoke InsertLst,g_BMLst,eax
    mov g_BMLst, eax  
    
    invoke crt_printf,offset g_szShowFmtBM,dwAddr,dwLen,btHpType,@dwOldProtect,@bReset
    ret
OnBMCommand endp
;-----------------BMC 删除内存断点--------------
OnBMCCommand proc uses ecx edx ebx esi edi dwNum:DWORD

    
    invoke DeleteUseIdxLst, g_BMLst, dwNum
    mov g_BMLst, eax

    ret
OnBMCCommand endp
;-----------------BML 内存断点--------------
OnBMLCommand proc uses ecx edx ebx esi edi
    LOCAL @index:DWORD
    ;invoke crt_printf,offset g_TestBML
      invoke crt_printf, offset g_szBPPrint
    
    mov esi, g_BMLst
    assume esi:ptr Node
    
    mov @index,0
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBMCommand
        
        invoke crt_printf,offset g_szShowBPLst,@index,[eax].m_dwAddr
        inc @index
        assume eax:nothing
        
        mov esi, [esi].m_pNext
    .endw
    
    ret
OnBMLCommand endp
;-----------------BH 硬件断点-------------------
OnBHCommand proc uses ecx edx ebx esi edi dwAddr:DWORD,dwLen:DWORD,btHpType:DWORD

    invoke SetBh,dwAddr,dwLen,btHpType    
    .if eax
        ;将断点信息插入链表
        invoke crt_malloc, sizeof tagBhCommand 
        assume eax:ptr tagBhCommand
        mov ebx,dwAddr
        mov [eax].m_dwAddr,ebx
        mov ebx,dwLen
        mov [eax].m_dwLen,ebx
        mov ebx,btHpType
        mov [eax].m_btType,ebx
        assume eax:nothing
    
        invoke InsertLst,g_BhLst,eax
        mov g_BhLst, eax  
        
        mov ebx,dwLen
        inc ebx
       
        .if btHpType==0
            invoke crt_printf,offset g_szShowFmtBH,dwAddr,ebx
            invoke crt_printf,offset g_szbhType0 
        .endif 
        .if btHpType==1
            invoke crt_printf,offset g_szShowFmtBH,dwAddr,ebx,g_szbhType1 
            invoke crt_printf,offset g_szbhType1
        .endif 
        .if btHpType==3
            invoke crt_printf,offset g_szShowFmtBH,dwAddr,ebx,g_szbhType3
            invoke crt_printf,offset g_szbhType3
        .endif
    .else
        invoke crt_printf,offset g_szSetBhNumbError  
    .endif
    
    
    ret
OnBHCommand endp
;-----------------BHL 显示硬件断点------------
OnBHLCommand proc
    LOCAL @i:DWORD
    LOCAL @index:DWORD
    
    mov esi, g_BhLst
    assume esi:ptr Node
    
    invoke crt_printf, offset g_szBPPrint
    mov @index,0
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBpCommand
        
        invoke crt_printf,offset g_szShowBPLst,@index,[eax].m_dwAddr
        inc @index
        assume eax:nothing
        
        mov esi, [esi].m_pNext
    .endw
    
    ;invoke crt_printf,offset g_TestBHL
    
    ret
OnBHLCommand endp
;-----------------BHC 删除硬件断点------------
OnBHCCommand proc dwNum:DWORD
 local @nTheFew
    local @nSize
    local @nSuccess
    local @ctx:CONTEXT
     
    ;取消硬件断点
    mov @ctx.ContextFlags,CONTEXT_ALL
    invoke GetThreadContext,m_hThread,addr @ctx
    
    .if dwNum == 1
        and @ctx.iDr7,0fffffffeh
    .elseif dwNum== 0
        and @ctx.iDr7,0fffffffbh
    .elseif dwNum== 2
        and @ctx.iDr7,0ffffffefh
    .elseif dwNum== 3
        and @ctx.iDr7,0ffffffbfh
    .endif
   

    mov @ctx.iDr6,0
    invoke SetThreadContext,m_hThread,addr @ctx ;改完设置回去
    
    invoke DeleteUseIdxLst, g_BhLst, dwNum
    mov g_BhLst, eax
    ret

OnBHCCommand endp
;-----------------TRACE脚本功能 trace+t/p+Addr t遇CALL进入，p遇CALL不入------------------------
OnTraceCommand proc uses ecx edx ebx esi edi 
    ;	hTraceFile= CreateFile("trace.txt",
	;GENERIC_WRITE | GENERIC_READ,0,NULL,CREATE_ALWAYS,0,NULL);
		
    invoke CreateFile,offset g_szTraceFile,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL 
    .if eax==0       
        invoke crt_printf,offset g_strCreateFileError
    .else
        mov m_hTraceFile,eax   
    .endif

    mov m_bTraceCmd,TRUE
    
    invoke crt_printf,addr g_szTrace
    invoke OnTCommand 
    ret
OnTraceCommand endp
;-----------------T-单步步入------------------
OnTCommand proc uses ecx edx ebx esi edi 
;	m_bSingStepCmd = TRUE;
;	//设置单步标志
;	SetTFAndDecEip();
    
    mov m_bSingStepCmd,1
    ;设置单步
     invoke SetTFAndDecEip,0
    ret
OnTCommand endp
;-----------------P 单步步过-------------------
OnPCommand proc uses ecx edx ebx esi edi 

;	//判断是否是call
;	if (strstr(szAsm, "call") != NULL)
;	{

;	}
;	else
;	{
;		SetTFAndDecEip();
;		m_bSingStepCmd = TRUE;
;	}
    LOCAL @pAddr:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @nAsmLen:DWORD
    LOCAL @aryCode[16]:DWORD
    LOCAL @szAsm[MAXBYTE]:DWORD
    LOCAL @strOpcode[MAXBYTE]:DWORD   
    LOCAL @dwNextAddr:DWORD
    LOCAL @btOldCode:BYTE
    ;先反汇编判断是不是CALL
    mov @dwNextAddr,0
    mov @pAddr,0
    mov @dwBytesToRead,0
    mov @nAsmLen,0
    mov @btOldCode,0
    invoke RtlZeroMemory,addr @aryCode,16
    invoke RtlZeroMemory,addr @szAsm,sizeof @szAsm
    invoke RtlZeroMemory,addr @strOpcode,sizeof @strOpcode
    
    invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    invoke ReadProcessMemory,m_hProc,@pAddr,addr @aryCode,sizeof @aryCode,addr @dwBytesToRead
    .if eax==0
        ret
    .endif
    
    invoke Decode2AsmOpcode,addr @aryCode,addr @szAsm,addr @strOpcode,addr @nAsmLen,@pAddr
    invoke crt_strstr,addr @szAsm,offset g_Call
    
    .if eax!=0
        
        ;判断是否为trace T指令 ,遇到CALL也进入
        .if m_bTraceType==0 && m_bTraceCmd==1
            invoke SetTFAndDecEip,0
            mov m_bSingStepCmd,TRUE   
            mov eax,DBG_CONTINUE
            ret
            
        .endif
        
        ;DWORD dwNextAddr = (DWORD)pAddr + nAsmLen
        ;m_cmdTmp = { dwNextAddr,0,FALSE }
        ;SetBp(dwNextAddr, &m_cmdTmp.m_btOldCode)
        
        mov eax,@pAddr
        Add eax,@nAsmLen
        mov @dwNextAddr,eax
        ;设置临时断点     
        mov ebx,@dwNextAddr
        mov TempBp.m_dwAddr,ebx
        mov TempBp.m_btOldCode,0
        
        invoke SetBp,@dwNextAddr,@btOldCode
        mov @btOldCode,al
        mov bl,@btOldCode
        mov TempBp.m_btOldCode,bl   
        
    .else       
        invoke SetTFAndDecEip,0
        mov m_bSingStepCmd,TRUE       
        
    .endif
    
    mov eax,1
    ret
OnPCommand endp
;-----------------G 执行到指定地址-------------------
OnGCommand proc uses ecx edx ebx esi edi dwAddr:DWORD 

;	//设置临时断点
;	BYTE btOldCode = 0;
;	if (SetBp(dwAddr, &btOldCode))
;	{
;		m_cmdTmp = { dwAddr,btOldCode,FALSE };
;		return TRUE;
;	}
;	return FALSE;
    LOCAL @btOldCode:BYTE
    
    mov @btOldCode,0
    ;设置临时断点           
    invoke SetBp,dwAddr,@btOldCode     
    .if al
        mov @btOldCode,al   
         
        mov ebx,dwAddr
        mov TempBp.m_dwAddr,ebx
        mov bl,@btOldCode
        mov TempBp.m_btOldCode,bl

        ret
    .endif
    
    ret
OnGCommand endp
;-----------------U+addr显示指定地址16条反汇编--------------------
OnUCommand proc uses ecx edx ebx esi edi dwAddr:DWORD
;	for (UINT i = 0; i < 16; i++)
;	{
;		BYTE aryCode[16] = {};
;		DWORD dwBytesToRead = 0;
;		ReadProcessMemory(m_hProc, (LPVOID)dwAddr, aryCode, sizeof(aryCode), &dwBytesToRead);
;		char szAsm[MAXBYTE] = {};
;		UINT nAsmLen = 0;
;		Decode2Asm(aryCode, szAsm, &nAsmLen, (UINT)dwAddr);
;
;		printf("[INF]: %p %s \r\n", (LPVOID)dwAddr, szAsm);
;
;		dwAddr = (UINT)dwAddr + nAsmLen;
;	}
;	dwTempAddr = dwAddr;
;
;	return ;
    LOCAL @pAddr:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @i:DWORD
    LOCAL @nAsmLen:DWORD
    LOCAL @aryCode[16]:DWORD
    LOCAL @szAsm[MAXBYTE]:DWORD
    LOCAL @strOpcode[MAXBYTE]:DWORD   
    LOCAL @nAddr:DWORD
    
    ;初始化       
    mov @i,0
    mov ecx,@i
    .while ecx<16
        
        mov @dwBytesToRead,0
        mov @nAsmLen,0
        invoke RtlZeroMemory,addr @aryCode,16
        invoke RtlZeroMemory,addr @szAsm,sizeof @szAsm
        invoke RtlZeroMemory,addr @strOpcode,sizeof @strOpcode
           
        invoke ReadProcessMemory,m_hProc,dwAddr,addr @aryCode,sizeof @aryCode,addr @dwBytesToRead
        .if eax==0
             ret
        .endif
    
        invoke Decode2AsmOpcode,addr @aryCode,addr @szAsm,addr @strOpcode,addr @nAsmLen,dwAddr           
        invoke crt_printf, offset g_szPrintAsm, dwAddr, addr @szAsm	
     
        mov ebx,dwAddr
        ADD ebx,@nAsmLen    
        mov dwAddr,ebx
             
        inc @i
        mov ecx,@i
    .endw
    
    mov ebx,dwAddr
    mov g_dwTempAddr,ebx
    
    ret
OnUCommand endp
;-----------------U 显示当前地址16条反汇编------------------------
OnUCommand0 proc uses ecx edx ebx esi edi 
    ;	LPVOID pAddr = m_de.u.Exception.ExceptionRecord.ExceptionAddress;
;
;	for (UINT i = 0; i < 16; i++)
;	{
;		BYTE aryCode[16] = {};
;		DWORD dwBytesToRead = 0;
;		ReadProcessMemory(m_hProc, pAddr, aryCode, sizeof(aryCode), &dwBytesToRead);
;		char szAsm[MAXBYTE] = {};
;		UINT nAsmLen = 0;
;		Decode2Asm(aryCode, szAsm, &nAsmLen, (UINT)pAddr);
;		printf("[INF]: %p %s \r\n", pAddr, szAsm);
;
;		UINT npAddr =(UINT)pAddr+ nAsmLen;
;		pAddr = (LPVOID)npAddr;
;	}
;	dwTempAddr = (DWORD)pAddr;
;
;	return ;
    LOCAL @pAddr:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @i:DWORD
    LOCAL @nAsmLen:DWORD
    LOCAL @aryCode[16]:DWORD
    LOCAL @szAsm[MAXBYTE]:DWORD
    LOCAL @strOpcode[MAXBYTE]:DWORD   
    LOCAL @nAddr:DWORD
       
              
    ;初始化         
    mov @pAddr,0
    invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    
    mov @i,0
    mov ecx,@i
    .while ecx<16
        
        mov @dwBytesToRead,0
        mov @nAsmLen,0
        invoke RtlZeroMemory,addr @aryCode,16
        invoke RtlZeroMemory,addr @szAsm,sizeof @szAsm
        invoke RtlZeroMemory,addr @strOpcode,sizeof @strOpcode
           
        invoke ReadProcessMemory,m_hProc,@pAddr,addr @aryCode,sizeof @aryCode,addr @dwBytesToRead
        .if eax==0
            invoke crt_printf,offset g_strReadError
            ret
        .endif
    
        invoke Decode2AsmOpcode,addr @aryCode,addr @szAsm,addr @strOpcode,addr @nAsmLen,@pAddr
              
        invoke crt_printf, offset g_szPrintAsm, @pAddr, addr @szAsm	
     
        mov ebx,@pAddr
        ADD ebx,@nAsmLen    
        mov @pAddr,ebx
             
        inc @i
        mov ecx,@i
    .endw
    
    mov ebx,@pAddr
    mov g_dwTempAddr,ebx
    
    ret
OnUCommand0 endp
;-----------------R 显示寄存器信息----------------------
OnRCommand proc uses ecx edx ebx esi edi 


;	CONTEXT ctx;
;	FLAGS_REGISTER Flags;
;	ctx.ContextFlags = CONTEXT_ALL;
;
;	if (GetThreadContext(m_hThread, &ctx))
;	{
;		Flags.Flags = ctx.EFlags;
;		printf("EAX = %08X  EBX = %08X  ECX = %08X  EDX = %08X  ESI = %08X  EDI = %08X\r\n",
;			ctx.Eax, ctx.Ebx, ctx.Ecx, ctx.Edx, ctx.Esi, ctx.Edi);
;
;		printf("EIP = %08X  ESP = %08X  EBP = %08X  ZF  PF  AF  OF  SF  DF  CF  TF  IF\r\n",
;			ctx.Eip, ctx.Esp, ctx.Ebp, ctx.Edx, ctx.Esi, ctx.Edi);
;		printf("                                                %02X  %02X  %02X  %02X  %02X  %02X  %02X  %02X  %02X\r\n",
;            (ctx.EFlags&64)  / 64,
;            (ctx.EFlags&128)  / 128););
;
;		printf("CS = %04X  SS = %04X  DS = %04X  ES = %04X  FS = %04X   GS = %04X\r\n",
;			ctx.SegCs, ctx.SegSs, ctx.SegDs, ctx.SegEs, ctx.SegFs, ctx.SegGs);
;	}
;
;	return TRUE;

    LOCAL @ctx:CONTEXT
    LOCAL @i:DWORD
    LOCAL @CF:DWORD
    LOCAL @PF:DWORD
    LOCAL @AF:DWORD
    LOCAL @ZF:DWORD
    LOCAL @SF:DWORD
    LOCAL @TF:DWORD
    LOCAL @IF:DWORD
    LOCAL @DF:DWORD
    LOCAL @OF:DWORD
    LOCAL @n:DWORD
    ;LOCAL @teflag:tagEFlags

    ;初始化
    mov @n,0
    invoke RtlZeroMemory,addr @ctx ,sizeof @ctx
    
    mov @ctx.ContextFlags,CONTEXT_ALL 
    invoke GetThreadContext,m_hThread,addr @ctx
    .if eax==0
        invoke crt_printf,offset g_szPrintRegError	
        ret
    .endif
        
    mov eax,@ctx.regFlag
    AND eax,1
    mov ebx,1
    DIV ebx
    mov @CF,eax
    
    mov eax,@ctx.regFlag
    AND eax,4
    mov ebx,4
    DIV ebx
    mov @PF,eax
    
    mov eax,@ctx.regFlag
    AND eax,16
    mov ebx,16
    DIV ebx
    mov @AF,eax
    
    mov eax,@ctx.regFlag
    AND eax,64
    mov ebx,64
    DIV ebx
    mov @ZF,eax
    
    mov eax,@ctx.regFlag
    AND eax,128
    mov ebx,128
    DIV ebx
    mov @SF,eax

    mov eax,@ctx.regFlag
    AND eax,256
    mov ebx,256
    DIV ebx
    mov @TF,eax
    
    mov eax,@ctx.regFlag
    AND eax,512
    mov ebx,512
    DIV ebx
    mov @IF,eax
    
    mov eax,@ctx.regFlag
    AND eax,1024
    mov ebx,1024
    DIV ebx
    mov @DF,eax
    
    mov eax,@ctx.regFlag
    AND eax,2056
    mov ebx,2056
    DIV ebx
    mov @OF,eax
    
    
    invoke crt_printf,offset g_szPrintReg_1, @ctx.regEax, @ctx.regEbx, @ctx.regEcx, @ctx.regEdx, @ctx.regEsi, @ctx.regEdi
    invoke crt_printf,offset g_szPrintSign, @ctx.regEip, @ctx.regEsp, @ctx.regEbp
    invoke crt_printf,offset g_szPrintSignInfo,@CF,@PF,@AF,@ZF,@SF,@TF,@IF,@DF,@OF
    invoke crt_printf,offset g_szPrintReg_2, @ctx.regCs, @ctx.regSs, @ctx.regDs, @ctx.regEs, @ctx.regFs, @ctx.regGs
    
    ret
OnRCommand endp
;-----------------Ret 返回到执行--------------------
OnRet proc uses ecx edx ebx esi edi 
    LOCAL  @dwAddr:DWORD
    LOCAL  @arybtCode[32]:BYTE
    LOCAL  @szAsm[MAXBYTE]:BYTE
    LOCAL  @dwAsmLen:DWORD
    LOCAL  @aryMachCode[132]:BYTE
    LOCAL  @dwBytesToRead:DWORD
    invoke RtlZeroMemory,addr @aryMachCode,16

    mov @dwAddr,0
    invoke crt_memcpy,addr @dwAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @dwAddr
    
    invoke ReadProcessMemory,m_hProc,@dwAddr,addr @arybtCode, sizeof @arybtCode,addr @dwBytesToRead
    .if eax== 0
          invoke crt_printf,offset g_szPrintRegError
          ret
    .endif

    invoke Decode2AsmOpcode,addr @arybtCode,addr @szAsm,addr @aryMachCode,addr @dwAsmLen,@dwAddr
    lea eax,@aryMachCode
    .if   WORD PTR [eax] == '3C'
            mov eax,TRUE
    .else
            mov eax ,FALSE
    .endif
    ret

OnRet endp 
;-----------------O-dump脱壳 -----     
OnDump proc uses ecx edx ebx esi edi 
    LOCAL @dwBytesToRead
    LOCAL @dwOldProct
    LOCAL @dwSecBase
    LOCAL @dwAddr
    LOCAL @dwSecCount
	LOCAL @dwSecSize
	LOCAL @dwSecAddr
	LOCAL @dwSecAddrSize
	LOCAL @dwAddrSize
    LOCAL @dwFileSize
    LOCAL @i
    
    mov @dwBytesToRead,0
    mov @dwOldProct,0
    mov @dwSecBase,0
    mov @dwAddr,0
    mov @dwSecAddrSize,0
	mov @dwAddrSize,0
	mov @i,0

    ;创建一个新的PE文件    
    invoke CreateFile, offset g_szDumpFile, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL 
    
    .if eax!=INVALID_HANDLE_VALUE
        invoke CloseHandle,eax
    .endif

    ;获取SecBase
    movzx ebx,[g_pImgFileHdr].SizeOfOptionalHeader
    ADD ebx,g_pImgBase
    ADD ebx,24  ;加24到OptionalHeader的首地址   
    mov @dwSecBase,ebx
    

    ;写PE头
    invoke crt_malloc, [g_pImgOptionalHdr].SizeOfHeaders
    mov ebx,eax
    invoke ReadProcessMemory,m_hProc,g_dwModule,ebx, [g_pImgOptionalHdr].SizeOfHeaders, addr @dwBytesToRead
    invoke WritePEFile,ebx,[g_pImgOptionalHdr].SizeOfHeaders
    invoke crt_free, ebx
      
    ;写入节
    movzx ecx,[g_pImgFileHdr].NumberOfSections
    .while @i < ecx
        invoke ReadProcessMemory,m_hProc,@dwSecBase,addr g_pImgSecHdr, sizeof(IMAGE_SECTION_HEADER), addr @dwBytesToRead
        mov ebx,g_dwModule
        mov @dwAddr,ebx
        mov eax,[g_pImgSecHdr].VirtualAddress
        ADD @dwAddr,eax
        
        ;没有数据
        .if [g_pImgSecHdr].SizeOfRawData == 0      
            mov eax,sizeof(IMAGE_SECTION_HEADER)
            ADD @dwSecBase,eax
            .continue
        .endif
        
        lea ebx,g_pImgSecHdr
        assume ebx: ptr IMAGE_SECTION_HEADER 
        mov eax,[g_pImgOptionalHdr].SectionAlignment
        ;如果大于节点大小
        .if [ebx].Misc.VirtualSize > eax
            ;初始化节区数据
            mov @dwSecCount,0
            mov @dwSecSize,0
            mov @dwSecAddr,0
            mov @dwSecAddrSize,0
            
            ;计算多少数据写到文件
            mov ecx,[g_pImgOptionalHdr].SectionAlignment
            mov eax,[ebx].Misc.VirtualSize
            mov edx,0
            div ecx
            mov @dwSecCount,eax
            .if edx != 0
                mov @dwSecAddr,1
            .endif
            mov eax,@dwSecCount
            ADD eax,@dwSecAddr
            mov @dwSecCount,eax
            
            mov ecx,[g_pImgOptionalHdr].FileAlignment
            mov eax,[ebx].SizeOfRawData
            mov edx,0
            div ecx
            mov @dwSecSize,eax
            .if edx != 0
                mov @dwSecAddrSize,1
            .endif
            mov eax,@dwSecSize
            ADD eax,@dwSecAddrSize
            mov @dwSecSize,eax
            
            ;写入文件
            mov eax,@dwSecCount
            mul [g_pImgOptionalHdr].SectionAlignment
            mov @dwAddrSize,eax
            
            mov eax,@dwSecSize
            mul [g_pImgOptionalHdr].FileAlignment
            mov @dwFileSize,eax
            
            invoke crt_malloc, @dwAddrSize
            mov ebx,eax
            invoke ReadProcessMemory,m_hProc,@dwAddr,ebx, @dwAddrSize, addr @dwBytesToRead
            invoke WritePEFile,ebx,@dwFileSize
            invoke crt_free, ebx
        .else
            invoke crt_malloc, [g_pImgOptionalHdr].SectionAlignment
            mov ebx,eax
            invoke ReadProcessMemory,m_hProc,@dwAddr,ebx, [g_pImgOptionalHdr].SectionAlignment, addr @dwBytesToRead
            invoke WritePEFile,ebx,[g_pImgOptionalHdr].SizeOfHeaders
            invoke crt_free, ebx
        .endif
        
        ;增加节偏移
        mov eax,sizeof IMAGE_SECTION_HEADER
        ADD @dwSecBase,eax
        ADD @i,1
        movzx ecx,[g_pImgFileHdr].NumberOfSections
    .endw
      
    ret
OnDump endp
;-----------------SS 脚本保存------------
OnSSCommand proc uses ecx edx ebx esi edi 
    LOCAL @i:DWORD
    LOCAL @bytesWritten:DWORD
    LOCAL @nLen:DWORD
    
    .if g_nNumberofCmd==0
        invoke crt_printf,offset g_SzScripNull 
        ret
    .endif
     
     invoke CreateFile,offset g_szScriptFile,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL 
    .if eax==0       
        invoke crt_printf,offset g_strCreateFileError
    .else
        mov m_hScriptFile,eax   
    .endif
      
    mov @i,1
    mov ecx,@i
    lea ebx,g_szScriptBuffer  
    .while ecx<g_nNumberofCmd
        
        invoke crt_strlen,ebx  
        mov @nLen,eax      
        
        ;invoke crt_printf,ebx
        invoke SetFilePointer,g_szScriptFile,0,NULL,FILE_END
        invoke WriteFile,m_hScriptFile,ebx,@nLen,@bytesWritten,NULL   
        ;invoke crt_printf,offset g_szBpLen,@nLen
        ;invoke crt_printf,offset g_szBpLen,@bytesWritten
        .if eax ==0
            invoke crt_printf,offset g_strWriteError
            ret
        .endif
        
        ADD ebx,32
        inc @i   
        mov ecx,@i 
    .endw
 
    .if m_hScriptFile!=0     
        invoke CloseHandle,m_hScriptFile ;关闭文件句柄
    .endif
    ret
OnSSCommand endp
;-----------------SR 脚本读取------------
OnSRCommand proc uses ecx edx ebx esi edi 
    LOCAL @i:DWORD
    LOCAL @j:DWORD
    LOCAL @bytesWritten:DWORD
    LOCAL @pCmd[32]:DWORD
    LOCAL @len:DWORD
    LOCAL @pCmdTemp[256]:DWORD 
    LOCAL @pCmdstr:DWORD
    
    mov @pCmdstr,0
    mov @len,0
    invoke RtlZeroMemory,addr g_szScriptRead,1000
    invoke RtlZeroMemory,addr @pCmd,32
    invoke RtlZeroMemory,addr @pCmdTemp,256
    
    invoke CreateFile,offset g_szScriptFile,GENERIC_READ,0,NULL,OPEN_EXISTING,0,NULL 
    .if eax==INVALID_HANDLE_VALUE      
        invoke crt_printf,offset g_strCreateFileError
        ret
    .endif
    
     mov m_SciptFile,eax   
     ;打开脚本读取标志
     mov m_bIsReadScript,1   
        
            
     invoke ReadFile,m_SciptFile,addr g_szScriptRead,1000,addr @bytesWritten,NULL
    .if eax==0       
        invoke crt_printf,offset g_strCreateFileError
        ret  
    .endif
    
    .if m_SciptFile!=INVALID_HANDLE_VALUE    
        invoke CloseHandle,m_SciptFile ;关闭文件句柄
    .endif

    ret
OnSRCommand endp
;-----------------E 修改内存信息-------------------
OnECommand proc uses ecx edx ebx esi edi dwAddr:DWORD
    LOCAL @szBuff:DWORD
    LOCAL @i:DWORD
    LOCAL @j:DWORD
    LOCAL @n:DWORD
    LOCAL @SetCode[32]:DWORD
    LOCAL @szCode:ptr
    LOCAL @ptr:ptr
    LOCAL @btCode:byte       
    LOCAL @dwOldProc:DWORD
    LOCAL @dwBytesToRead:DWORD
    LOCAL @dwBytesToWrite:DWORD
    LOCAL @CodeLen:DWORD
    LOCAL @Len:DWORD

    mov @Len,0
    mov @dwOldProc,0    
    mov @szCode,0
    mov @i,0
    mov @j,0    
    mov eax,offset g_SetCode
    mov @szBuff,eax
     
    invoke RtlZeroMemory,addr @SetCode,32   
    mov eax,offset g_AsciiCode
    mov @ptr,eax
    mov @szCode,eax

    mov ecx,@i   
    mov ebx,@szBuff
    mov al,BYTE PTR [ebx]
    
    .while al!=00h
        mov ebx,@szBuff
        mov al,BYTE PTR [ebx]
        inc @szBuff
        mov edx,@szBuff
        mov cl,BYTE PTR [edx]
        
        .if al>=30h && al<=39h
            sub al,30h
            mov bl,10h
            mul bl         
            .if cl>=30h && cl<=39h
                sub cl,30h
                ADD al,cl    
            .elseif dl>=41h && cl<=46h
                sub cl,37h   
                ADD al,cl
            .elseif cl>=61h && cl<=66h 
                sub cl,59h
                ADD al,cl
            .endif
           mov @btCode,al
           invoke crt_memcpy,@ptr,addr @btCode,1 ;1,2,3
           
        .elseif al>=41h && al<=46h
            sub al,37h
            mov bl,10h
            mul bl 
            .if cl>=30h && cl<=39h
                sub cl,30h
                ADD al,cl    
            .elseif cl>=41h && cl<=46h
                sub cl,37h   
                ADD al,cl
            .elseif cl>=61h && cl<=66h 
                sub cl,57h
                ADD al,cl
            .endif
           mov @btCode,al
           
           invoke crt_memcpy,@ptr,addr @btCode,1 ;,A,B,C
        .elseif al>=61h && al<=66h
            sub al,57h
            mov bl,10h
            mul bl 
            .if cl>=30h && cl<=39h
                sub cl,30h
                ADD al,cl    
            .elseif cl>=41h && cl<=46h
                sub cl,37h   
                ADD al,cl
            .elseif cl>=61h && cl<=66h 
                sub cl,57h
                ADD al,cl
            .endif
           ;mov byte ptr [@ptr],al
           ;invoke crt_memcpy,@szCode,@btCode,1    
             mov @btCode,al

        invoke crt_memcpy,@ptr,addr @btCode,1   ;a,b,c
        .endif
        inc @j
        inc @ptr
        inc @SetCode
        inc @szBuff
    .endw

    invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,PAGE_EXECUTE,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
     mov @dwBytesToWrite,0
     dec @j
     invoke WriteProcessMemory,m_hProc,dwAddr,addr g_AsciiCode,@j,addr @dwBytesToWrite
    .if eax==0
        invoke crt_printf,offset g_strWriteError 
    .endif
    
     invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,@dwOldProc,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
    ret  

OnECommand endp
;-----------------D 显示内存信息-------------------
OnDCommand proc uses ecx edx ebx esi edi dwAddr:DWORD

    LOCAL @pAddr:DWORD
    LOCAL @aryCode[128]:BYTE
    LOCAL @dwBytesToRead:DWORD
    LOCAL @i:DWORD
    LOCAL @j:DWORD
    
    mov @dwBytesToRead,0
    mov @pAddr,0
    invoke RtlZeroMemory,addr @aryCode,128
    
    .if dwAddr==0
        invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    .else
        mov eax,dwAddr
        mov @pAddr,eax
    .endif
    
    invoke ReadProcessMemory,m_hProc,@pAddr,addr @aryCode,sizeof @aryCode,addr @dwBytesToRead
    ;.if eax==0
        ;invoke crt_printf,offset g_strReadError
        
        ;ret
    ;.endif
    
    mov @i,0
    mov ecx,@i
    .while ecx < 5
        mov eax,@i
        mov ebx,16
        mul ebx
        ADD eax,@pAddr
        invoke crt_printf,offset g_szPrintHex8,eax  
        mov @j,0
        mov ecx,@j    
        .while ecx < 16    
            mov eax,@i
            mov ebx,16
            mul ebx
            ADD eax,@j
            invoke crt_printf,offset g_szPrintHex2,@aryCode+BYTE ptr [eax]
            inc @j
            mov ecx,@j     
        .endw
        invoke crt_printf,offset g_szPrintSpace


        mov @j,0
        mov ecx,@j
        .while ecx < 16
            mov eax,@i
            mov ebx,16
            mul ebx
            ADD eax,@j
            mov al,@aryCode+BYTE ptr [eax]
            .if  al >= 32 && al<=128
                invoke crt_printf,offset g_szPrintChar,al
            .else
                invoke crt_printf,offset g_szPrintPoint
            .endif
            inc @j
            mov ecx,@j
        .endw
        
        invoke crt_printf,offset g_szPrintNextLen
        
        inc @i
        mov ecx,@i
    .endw
    ret
OnDCommand endp
;-----------------DL 显示模块DLL
OnShowDLL proc uses ecx edx ebx esi edi
    LOCAL @hProcessSnap:HANDLE
    LOCAL @hModuleSnap:HANDLE
    LOCAL @pe:PROCESSENTRY32 
    LOCAL @pNext:DWORD
    LOCAL @me32:MODULEENTRY32
    LOCAL @mNext:DWORD
    
     ;invoke crt_printf,offset g_szWss,g_szShowDLL
;    HANDLE  hsnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
;    if(hsnapshot == INVALID_HANDLE_VALUE) 
;    {   
;        printf("CreateToolhelp32Snapshot Error!\n");
;        return 0;  
;    }
    invoke crt_printf,offset g_szShowDLL
    invoke CreateToolhelp32Snapshot,TH32CS_SNAPPROCESS,0  ;获取进程快照句柄
    mov @hProcessSnap,eax
    .if @hProcessSnap==INVALID_HANDLE_VALUE
        invoke crt_printf,offset g_szGetDProError 
    .endif
    
;    PROCESSENTRY32 pe;
;    pe.dwSize = sizeof(PROCESSENTRY32);
     mov @pe.dwSize,sizeof PROCESSENTRY32
;    while (Process32Next(h ProcessSnap,&process)){

;        string s_szExeFile = process.szExeFile; // char* 转 string
;		if(s_szExeFile == "QQMusic.exe"){
;			// 初始化
;			CString strModule;	// 模块名称
;			HANDLE  hModuleSnap  =  ::CreateToolhelp32Snapshot(TH32CS_SNAPMODULE,process.th32ProcessID); 	// 模块快照句柄
;			MODULEENTRY32 me32 = {0};  // 模块入口
;			me32.dwSize = sizeof(MODULEENTRY32);  // 申请空间
;			
;			// 打印模块名
;			while(::Module32Next(hModuleSnap,&me32)){
;				strModule.Format("%s",me32.szModule);
;				cout << strModule.GetBuffer() << endl;
;			}   
    invoke Process32First,@hProcessSnap,addr @pe
    mov @pNext,eax 
    
    .while @pNext
    
         invoke crt_strcmp,addr @pe.szExeFile,addr g_szProcExe
        .if eax==0
            invoke CreateToolhelp32Snapshot,TH32CS_SNAPMODULE,@pe.th32ProcessID  ; 	// 获取模块快照句柄
            mov @hModuleSnap,eax 
            
            invoke RtlZeroMemory,addr @me32,sizeof MODULEENTRY32 ;申请Dll空间
            mov @me32.dwSize,sizeof MODULEENTRY32
            
            .if @hModuleSnap==INVALID_HANDLE_VALUE
                invoke crt_printf,offset g_szGetDllError
            .endif   
            
            invoke Module32First,@hModuleSnap,addr @me32
            invoke Module32Next,@hModuleSnap,addr @me32
            mov @mNext,eax
            
            .while @mNext
                
                invoke crt_printf,offset g_szWss,addr @me32.szModule
                
                invoke Module32Next,@hModuleSnap,addr @me32
                mov @mNext,eax
            .endw
                        
        .endif
        
        
        invoke Process32Next,@hProcessSnap,addr @pe
        mov @pNext,eax      
    .endw    
        
    ret
OnShowDLL endp
;-----------------h 显示帮助文档--------
OnHCommand proc uses ecx edx ebx esi edi
	invoke crt_printf, offset g_szHelp1
	invoke crt_printf, offset g_szHelp2
	invoke crt_printf, offset g_szHelp3
	invoke crt_printf, offset g_szHelp4
	invoke crt_printf, offset g_szHelp5
	invoke crt_printf, offset g_szHelp6
	invoke crt_printf, offset g_szHelp7
	invoke crt_printf, offset g_szHelp8
	invoke crt_printf, offset g_szHelp9
	invoke crt_printf, offset g_szHelp10
	invoke crt_printf, offset g_szHelp11
	invoke crt_printf, offset g_szHelp12
	invoke crt_printf, offset g_szHelp13
	invoke crt_printf, offset g_szHelp14
	invoke crt_printf, offset g_szHelp15
	invoke crt_printf, offset g_szHelp16
	invoke crt_printf, offset g_szHelp17  
	invoke crt_printf, offset g_szHelp18
	invoke crt_printf, offset g_szHelp19 
    invoke crt_printf, offset g_szHelp20
    ret
OnHCommand endp
;-----------------跳空格------------------------------------------
SkipWhiteChar proc uses ecx edx ebx esi edi pCommand: DWORD
;char* CDebugger::SkipWhiteChar(char* pCommand)
;{
;	while (*pCommand == ' ' || *pCommand == '\t')
;	{
;		++pCommand;
;	}
;	return pCommand;
;}
    mov eax,pCommand
    mov al,byte ptr [eax]
    .while al==32 || al ==9
        inc pCommand
        mov al,byte ptr [eax]
    .endw
    
    mov eax,pCommand
    ret
SkipWhiteChar endp
;-----------------输入命令---------------------------
; T步入 P步过 G/G+ADDR 执行
; U/U+ADDR 显示反汇编 
; D/D+ADDR 查看内存
; E+ADDR+CODE 修改内存
; R查看寄存器
; BP+ADDR IN3断点 BL查看 BC清除  
; R/R+ADDR 显示寄存器信息
; bh+Addr+1/2/4+a/e/w 硬件断点 BHL查看 BHC+1/2/3删除
; bm+addr+len+r/w  内存断点 BML查看 BPC+1/2/3删除
; Ret 执行到返回  
; TRACE+P/T+ADDR 记录指令
; SS脚本报存 SR脚本读取
; DUMP 脱壳Dump内存
; Q退出
; H查看帮助文档

InputCommand Proc uses ecx edx ebx esi edi ScrpitCmd:DWORD
    LOCAL @szCommand[32]:BYTE
    LOCAL @szBuffer[32]:DWORD
    LOCAL @szCmdBuffer[32]:DWORD
    LOCAL @pCmd:DWORD
    LOCAL @dwAddr:DWORD
    LOCAL @dwNum:DWORD
    LOCAL @dwBpAddr:DWORD
    LOCAL @dwBpLen:DWORD
    LOCAL @dwBpType:DWORD
    LOCAL @pCmdLen:DWORD
    LOCAL @BhEnd:DWORD
    LOCAL @BmEnd:DWORD
    LOCAL @m_bScriptQuit:DWORD
    LOCAL @dwCode:DWORD
    LOCAL @dwLen:DWORD
    LOCAL @i:DWORD
    LOCAL @j:DWORD
    LOCAL @SciptCmdptr:ptr
    LOCAL @CmdLen:DWORD
    LOCAL @SciptCmd:ptr
    ;mov @m_bScriptQuit,0
    ;m_bIsScriptFirst,1
    
.while 1
    mov @dwCode,0
    mov @pCmd,0
    mov @dwAddr,0
    mov @dwBpLen,0
    mov @dwBpType,0
    mov @dwBpLen,0
    mov @dwBpType,0
    mov @pCmdLen,0
    mov @dwLen,0
    mov @BhEnd,1
    mov @BmEnd,1
       
    invoke RtlZeroMemory,addr @szCommand,32
    invoke RtlZeroMemory,addr @szBuffer,32  
    invoke RtlZeroMemory,addr @szCmdBuffer,32  
    invoke RtlZeroMemory,addr g_SetCode,32
;    ;脚本执行一次就返回
;    .if @m_bScriptQuit==1
;        ret
;    .endif
    

    .if m_bIsReadScript==0
        ;正常输入命令
        invoke crt_printf, offset g_szInputInf,addr g_szInputInf
        
        invoke crt_gets, addr @szCommand ; 输入内容并接收参数        
        ;输入数据保存到g_szScriptBuffer数组，数量保存在g_nNumberofCmd      
        invoke wsprintf,addr @szCmdBuffer,offset g_szWss,addr @szCommand     ;格式化
    
        mov eax,32
        mov ebx,g_nNumberofCmd
        mul ebx
    
        lea ebx,g_szScriptBuffer
        ADD ebx,eax
        invoke crt_strcpy,ebx,addr @szCmdBuffer,32    ;指令保存到数组，用来生存指令脚本  
        inc g_nNumberofCmd       
        ;invoke crt_printf,offset g_szWss,@szCmdBuffer
        lea eax,@szCommand
    .else
        ;执行脚本
            
         ;mov ebx,offset g_szScriptRead   
          
        ;判断是否第一次执行脚本
            ;mov m_bIsScriptFirst,1  ;关闭第一次执行标志
            
            mov ebx,offset g_szScriptRead  
            mov @SciptCmdptr,ebx  ;读取指令的指针           
            mov @SciptCmd,ebx   
            
            mov eax,g_nScIndex
            ADD @SciptCmdptr,eax 
            ADD @SciptCmd,eax
            
            ;双指针 ，指针j用来保存每次拷贝的保存长度
            mov @j,0       
            mov ebx,@SciptCmdptr    
            mov al,byte ptr [ebx]
            .while al!=00h
                inc @j    ;指针j保存长度
                mov ebx,@SciptCmdptr
                mov al,byte ptr[ebx] 
                 .if al==0ah      
                    
                    mov eax,@j
                    dec eax        
                    invoke crt_memcpy,addr @szCommand,@SciptCmd,eax      
                    
                    mov eax,@j
                    ADD g_nScIndex,eax
                    ;invoke crt_printf, offset g_szBpLen,g_nScIndex
                                        
                    inc @SciptCmdptr
                    jmp  ReadScripting0
                .endif  
                inc @SciptCmdptr               
             .endw           
        
        mov m_bIsReadScript,0 ;关闭脚本读取
        ;mov m_bIsScriptFirst,0   
        mov @SciptCmdptr,0
        mov g_nScIndex ,0
        
        jmp SciptEnd0  ;所有脚本执行完毕

           
    ReadScripting0:                     
        invoke crt_printf, offset g_szScript,addr @szCommand  
    .endif
SciptEnd0:

    lea eax,@szCommand
    mov @pCmd,eax
    invoke SkipWhiteChar,@pCmd;跳过空格
	mov @pCmd,eax

	mov eax,@pCmd
	mov al,byte ptr [eax]
	
	.if al== 'b'||al=='B'
	    inc @pCmd    
	    mov eax,@pCmd
	    mov al,byte ptr [eax]
	    
	    .if al=='p'||al=='P' ;BP+dwAddr
	        inc @pCmd  
	        invoke SkipWhiteChar,@pCmd;跳过空格
	        mov @pCmd,eax
	        invoke crt_strtoul,@pCmd,NULL,16
	        mov @dwAddr,eax
	        
	        .if @dwAddr==0

	        .endif
	        
	        invoke OnBpCommand,@dwAddr;设置INT3 BP断点

	    .endif
	    
	    .if al=='l'|| al=='L';BL
	        invoke OnBLCommand
	    .endif
	    
	    .if al=='c'|| al=='C' ;BC+dwNum
	    	inc @pCmd  
	        invoke SkipWhiteChar,@pCmd;跳过空格
	        mov @pCmd,eax
	        invoke crt_strtoul,@pCmd,NULL,10
	        mov @dwNum,eax
            invoke OnBCCommand,@dwNum
         .endif  
         ;BH+Addr+1/2/4+a/e/w
         .if al=='h'||al=='H'
            inc @pCmd  
            mov eax,@pCmd
            mov al,byte ptr [eax]
            
            .if al =='L'||al=='l'
                invoke OnBHLCommand          
            .elseif al=='C'||al=='c'
	    	    inc @pCmd  
	            invoke SkipWhiteChar,@pCmd;跳过空格
	            mov @pCmd,eax
	            invoke crt_strtoul,@pCmd,NULL,10
	            mov @dwNum,eax
                invoke OnBHCCommand,@dwNum
            .else
            	invoke SkipWhiteChar,@pCmd
            	mov @pCmd,eax
        
            	invoke crt_strtoul,@pCmd,NULL,16 ;拿到地址
            	mov @dwBpAddr,eax
        	    .if @dwBpAddr==0
        		    jmp SetBHEnd0
        		.endif
        		
                invoke wsprintf,addr @szBuffer,offset g_szWsd,@dwBpAddr,addr @dwBpAddr ;计算地址的长度
                invoke crt_strlen,addr @szBuffer
                dec eax
                mov @pCmdLen,eax      
                ;invoke crt_printf,offset g_szBpLen,@pCmdLen
                mov eax,@pCmdLen       
                ADD @pCmd,eax           
            	invoke SkipWhiteChar,@pCmd
            	mov @pCmd,eax              	   
            	invoke crt_strtoul,@pCmd,NULL,16 ;拿到长度            	           	
            	mov @dwBpLen,eax                	   
			    sub @dwBpLen, 1
			   	
			   	.if !(@dwBpLen==0|| @dwBpLen==1|| @dwBpLen==3)
			     	;invoke crt_printf,offset g_szBpLen
			   	    jmp SetBHEnd0
			   	.endif
			   	
			   	inc @pCmd					   	 
                invoke SkipWhiteChar,@pCmd
                
                mov @pCmd,eax                        
                mov eax,@pCmd
                mov al,byte ptr [eax]
                  
                .if al=='a'  ;写入硬件断点
                    mov @dwBpType,1 ;二进制的11                
                .elseif al=='e'  ;执行硬件断点
                    mov @dwBpType,0 ;二进制的00
                    mov @dwBpLen,0
                .elseif al=='w'  ;读写硬件断点
                    mov @dwBpType,3 ;二进制的01
                .else
                    jmp SetBHEnd0                                 
                .endif
                
                mov @BhEnd,0  
                invoke OnBHCommand,@dwBpAddr,@dwBpLen,@dwBpType
        SetBHEnd0:
                .if @BhEnd
                    ;invoke crt_printf,offset g_szShowFmtBH,@dwBpAddr,@dwBpLen,@dwBpType
                    invoke crt_printf,offset g_szSetBhError ;设置硬件断点失败                    
                .endif
            .endif
                	         
         .endif
         ;BM+Addr+len+r/w
         .if al=='m'||al=='M'
            inc @pCmd  
            mov eax,@pCmd
            mov al,byte ptr [eax]
            
            .if al =='L'||al=='l'
                invoke OnBMLCommand          
            .elseif al=='C'||al=='c'
	    	    inc @pCmd  
	            invoke SkipWhiteChar,@pCmd;跳过空格
	            mov @pCmd,eax
	            invoke crt_strtoul,@pCmd,NULL,10
	            mov @dwNum,eax
                invoke OnBMCCommand,@dwNum
            .else
            	invoke SkipWhiteChar,@pCmd
            	mov @pCmd,eax
        
            	invoke crt_strtoul,@pCmd,NULL,16 ;拿到地址
            	mov @dwBpAddr,eax
        	    .if @dwBpAddr==0
        		    jmp SetBmEnd0
        		.endif
        		
                invoke wsprintf,addr @szBuffer,offset g_szWsd,@dwBpAddr,addr @dwBpAddr ;计算地址输入的长度
                invoke crt_strlen,addr @szBuffer
                dec eax
                mov @pCmdLen,eax
                ;invoke crt_printf,offset g_szBpLen,@pCmdLen
                mov eax,@pCmdLen       
                ADD @pCmd,eax           
            	invoke SkipWhiteChar,@pCmd
            	mov @pCmd,eax 
            	             	   
            	invoke crt_strtoul,@pCmd,NULL,10 ;拿到长度           	           	
            	mov @dwBpLen,eax                	   
			   	
			   	.if @dwBpLen==0
			   	    jmp SetBmEnd0
			   	.endif
			   	
			   	invoke RtlZeroMemory,addr @szBuffer,32       		
                invoke wsprintf,addr @szBuffer,offset g_szWsd,@dwBpLen,addr @dwBpLen ;计算长度输入的长度
                invoke crt_strlen,addr @szBuffer
                dec eax
                mov @pCmdLen,eax
			   	mov eax,@pCmdLen       
                ADD @pCmd,eax  
			   	
			   	inc @pCmd					   	 
                invoke SkipWhiteChar,@pCmd
                
                mov @pCmd,eax                        
                mov eax,@pCmd
                mov al,byte ptr [eax]
                  
                .if al=='r'||al=='R'  
                    mov @dwBpType,0            
                .elseif al=='w' ||al=='W' 
                    mov @dwBpType,1
                .else
                    jmp SetBmEnd0                                 
                .endif
                
                mov @BhEnd,0                
                invoke OnBMCommand,@dwBpAddr,@dwBpLen,@dwBpType
        SetBmEnd0:
                .if @BhEnd
                    invoke crt_printf,offset g_szSetBMError ;设置内存断点失败                    
                .endif
            .endif
                	         
         .endif 
            	
	.endif     
	     
	.if al=='u'|| al=='U'
	        
	    inc @pCmd
	    invoke SkipWhiteChar,@pCmd;跳过空格
	    mov @pCmd,eax
	    invoke crt_strtoul,@pCmd,NULL,16
	    mov @dwAddr,eax

	    .if @dwAddr==0	        
	        mov ebx,g_dwTempAddr
	        .if ebx==0 
	        	invoke OnUCommand0    ;当前地址第一次U     	           
	        .else  
	            invoke OnUCommand,g_dwTempAddr    ;当前地址连续U       
	        .endif
	        
	    .else
	        invoke OnUCommand,@dwAddr   ;U+dwAddr
	        
	    .endif

	 .endif
	
	.if al=='r'|| al=='R'           ;R
	    inc @pCmd
        mov eax,@pCmd
	    mov al,byte ptr [eax]
	    .if al=="e"|| al=='E'
	        inc @pCmd
	        mov eax,@pCmd
	        mov al,byte ptr [eax]
	        .if al=="t" || al=="t"
                invoke OnRet
	            
	        .endif	        
	    .else        
	        invoke OnRCommand
	    .endif
	.endif 
	
	.if al=='d' || al=='D'          ;D	
	    inc @pCmd
	    invoke SkipWhiteChar,@pCmd;跳过空格
	    mov @pCmd,eax
	    invoke crt_strtoul,@pCmd,NULL,16
	    mov @dwAddr,eax
	    
	    .if @dwAddr==0
	        invoke OnDCommand,0
	    .else
	        invoke OnDCommand,@dwAddr
	    .endif
	    	    
	.endif
	
    .if al=='o' || al=='O'          ;O dump
	    invoke OnDump	        	    
	.endif
	
	.if al=='l' || al=='L'
	    invoke OnShowDLL               ;L DLL
	.endif
	
	.if al=='e'|| al=='E'             ;E
	    inc @pCmd
        invoke SkipWhiteChar,@pCmd
        mov @pCmd,eax
        
        invoke crt_strtoul,@pCmd,NULL,16 ;拿到地址
        mov @dwAddr,eax
        .if @dwAddr==0
        	jmp SetEEnd0
        .endif
        		
        invoke wsprintf,addr @szBuffer,offset g_szWsd,@dwAddr,addr @dwAddr ;计算地址的长度
        invoke crt_strlen,addr @szBuffer
        dec eax
        mov @pCmdLen,eax      
        mov eax,@pCmdLen       
        ADD @pCmd,eax           
        invoke SkipWhiteChar,@pCmd
        ;mov @pCmd,eax              	   
        ;invoke crt_strtoul,@pCmd,NULL,16 ;  
        mov @dwCode,eax    ;拿到修改代码
                        		
        invoke crt_strlen,@dwCode
        mov @dwLen,eax 	
        invoke crt_memcpy,addr g_SetCode,@dwCode,@dwLen	 
        
        ;16进制转ASCII   
	    invoke OnECommand,@dwAddr
	    
	    jmp SetESuccess1     
	SetEEnd0:
	    invoke crt_printf,offset g_szSetEError    
	SetESuccess1:
	     
	.endif
	
	.if al=='t'||al=='T'             ;T    
        inc @pCmd
        mov eax,@pCmd
	    mov al,byte ptr [eax]
	    .if al=="r";
	        inc @pCmd
	        mov eax,@pCmd
	        mov al,byte ptr [eax]
	        .if al=="a"
	            inc @pCmd
	            mov eax,@pCmd
	            mov al,byte ptr [eax]
	            .if al=="c"
	                inc @pCmd
	                mov eax,@pCmd
	                mov al,byte ptr [eax]
	                .if al=="e"
	                    inc @pCmd
	                    invoke SkipWhiteChar,@pCmd;跳过空格
	                    mov @pCmd,eax
	                    invoke crt_strtoul,@pCmd,NULL,16    
	                    mov eax,@pCmd
	                    mov al,byte ptr [eax]
	                    
	                    .if al=="p"|| al=="P"
	                        mov m_bTraceType,1
	                        inc @pCmd
	                        invoke SkipWhiteChar,@pCmd;跳过空格
	                        mov @pCmd,eax
	                        invoke crt_strtoul,@pCmd,NULL,16
	                        mov g_dwEndTraceAddr,eax	                        
	                        invoke OnTraceCommand
	                        ret	                        
	                        
	                    .elseif al=="t"||al=="P"
	                        mov m_bTraceType,0
	                        inc @pCmd
	                        invoke SkipWhiteChar,@pCmd;跳过空格
	                        mov @pCmd,eax
	                        invoke crt_strtoul,@pCmd,NULL,16
	                        mov g_dwEndTraceAddr,eax	                        
	                        invoke OnTraceCommand
	                        ret
	                    .else
	                        invoke crt_printf,addr g_szTrace
	                        invoke crt_printf,offset g_strInputError
	                    .endif	                   
	                .endif   
	            .endif
	        .endif   
	    .else
	        invoke OnTCommand
	        ret
	    .endif
	.endif
	
	.if al=='p'||al=='P'             ;P  
	    invoke OnPCommand
	    ret
	.endif
	.if al=='S'||al=='s'             ;S
	    inc @pCmd    
	    mov eax,@pCmd
	    mov al,byte ptr [eax]	    
	    .if al=='S'||al=='s'
	        invoke OnSSCommand
	    .endif
	    .if al=='r'||al=='R'
            invoke OnSRCommand
        .endif      
	.endif
	
	.if al=='g'||al=='G'             ;G
	    inc @pCmd
	    invoke SkipWhiteChar,@pCmd;跳过空格
	    mov @pCmd,eax
	    invoke crt_strtoul,@pCmd,NULL,16
	    mov @dwAddr,eax

	    .if @dwAddr==0                 
	        ret
	    .endif
	    
	    invoke OnGCommand,@dwAddr     ;G+Addr
	    ret	    
	.endif
	
    .if al=='h'||al=='H'
	    invoke OnHCommand
	.endif

	.if al=='q'||al=='Q'             ;Q
	    invoke crt_exit,0
    
	.endif
.endw

    ret
InputCommand endp
;-------------------写PE DUMP文件--------
WritePEFile proc uses ecx edx ebx esi edi pBuff:dword,dwSize:dword
    LOCAL @nWite
    LOCAL @hflie
    invoke CreateFile, offset g_szDumpFile, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL 
    
    mov @hflie,eax                                    
    invoke SetFilePointer,@hflie, NULL, NULL, FILE_END
    invoke WriteFile,@hflie, pBuff, dwSize, addr @nWite , NULL
    invoke CloseHandle,@hflie
    ret
WritePEFile endp
;------------------恢复代码----------
OnResumeCode Proc uses ecx edx ebx esi edi dwAddr:DWORD,btOldCode:BYTE
    LOCAL @dwOldProc:DWORD
    LOCAL @dwBytesToWrite:DWORD
    
     invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,PAGE_READWRITE,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
     mov @dwBytesToWrite,0
     invoke WriteProcessMemory,m_hProc,dwAddr,addr btOldCode,sizeof btOldCode,addr @dwBytesToWrite
    .if eax==0
        invoke crt_printf,offset g_strWriteError 
    .endif
    
     invoke VirtualProtectEx,m_hProc,dwAddr,sizeof dwAddr,@dwOldProc,addr @dwOldProc
    .if eax==0
        invoke crt_printf,offset g_szVPError
    .endif
    
    
    ret
OnResumeCode endp
 ;-----------------恢复idr7寄存器状态-----------------
SetBhZero0 Proc uses ecx edx ebx esi edi BhIndex:DWORD 

    LOCAL @ctx:CONTEXT   
    
    invoke RtlZeroMemory,addr @ctx ,sizeof @ctx
    mov @ctx.ContextFlags,CONTEXT_ALL
    invoke GetThreadContext,m_hThread,addr @ctx   
    

     .if BhIndex==0
         OR @ctx.regFlag,100h
         AND @ctx.iDr7 ,0FFFFFFFCh
         mov @ctx.iDr6,0
         mov g_BhIndex._DR0 ,FALSE
    .elseif BhIndex==1
        OR @ctx.regFlag,100h
        AND @ctx.iDr7 ,0FFFFFFF3h
        mov @ctx.iDr6,0
        mov g_BhIndex._DR1 ,FALSE
    .elseif BhIndex==2
        OR @ctx.regFlag,100h
        AND @ctx.iDr7 ,0FFFFFFCFh
        mov @ctx.iDr6,0   
        mov g_BhIndex._DR2 ,FALSE
    .elseif BhIndex==3
        OR @ctx.regFlag,100h
        AND @ctx.iDr7 ,0FFFFFF3Fh
        mov @ctx.iDr6,0  
        mov g_BhIndex._DR3 ,FALSE  
    .endif
         
      
    invoke GetThreadContext,m_hThread,addr @ctx   
    ret

SetBhZero0 endp 
 ;----------------触发单步步异常------
OnSingleStep Proc uses ecx edx ebx esi edi
    LOCAL @pAddr:DWORD
    LOCAL @szCommand[32]:BYTE
    LOCAL @bIsBh:DWORD
    LOCAL @index:DWORD
    LOCAL @bmAddr:DWORD
    LOCAL @bmLen:DWORD
    LOCAL @dwOldProtect:DWORD
    LOCAL @ctx:CONTEXT
    LOCAL @dwResult:DWORD
    
    mov @dwResult,DBG_EXCEPTION_NOT_HANDLED 
    mov @dwOldProtect,0
    mov @bmAddr,0
    mov @bmLen,0
    mov @bIsBh,0
    mov @pAddr,0
    mov @index,0
    invoke RtlZeroMemory,addr @szCommand,32
    invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    
;重设INT3断点
   
    mov esi, g_BpLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBpCommand
        
        mov ebx,[eax].m_bReset
        .if ebx==1
            
            mov ebx,[eax].m_dwAddr
            mov cl,[eax].m_btOldCode
            invoke SetBp,ebx,cl
                 
            mov eax, [esi].m_pUserData
            assume eax:ptr tagBpCommand
            
            mov [eax].m_bReset,0
            mov @dwResult,DBG_CONTINUE
        .endif      
        assume eax:nothing     
        mov esi, [esi].m_pNext
    .endw

;重设内存断点
    mov esi, g_BMLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBMCommand
        
        mov ebx,[eax].m_bReset
        .if ebx==1
            mov [eax].m_bReset,0
            
            mov ebx,[eax].m_dwAddr
            mov @bmAddr,ebx
            mov ebx,[eax].m_dwLen
            mov @bmLen,ebx
            mov ebx,[eax].m_dwOldProtect
            mov @dwOldProtect,ebx
            
;           VirtualProtectEx(m_hProc,(LPVOID)cmd.m_dwAddr,cmd.m_dwLen,PAGE_NOACCESS,cmd.m_dwOldProtect);           
            invoke VirtualProtectEx,m_hProc,@bmAddr,@bmLen,PAGE_NOACCESS,addr @dwOldProtect  
            .if eax==0
                invoke crt_printf,offset g_BMSetFalied 
                ret
            .endif
                      
        .endif      
        assume eax:nothing     
        mov esi, [esi].m_pNext
        
        mov @dwResult,DBG_CONTINUE
    .endw
    
;重设硬件断点
    .if m_bBhSingStep
        ;//判断重设的是哪个断点，遍历链表看哪个需要重设
        mov esi, g_BhLst
        assume esi:ptr Node   
        .while esi != NULL
        
            mov edi, [esi].m_pUserData
            assume edi:ptr tagBhCommand
        
            .if  [edi].m_dwReset == TRUE
              mov [edi].m_dwReset,0
              invoke SetBh,[edi].m_dwAddr,[edi].m_dwLen,[edi].m_btType

              mov @dwResult,DBG_CONTINUE
            .endif
            assume edi:nothing
    
            mov esi, [esi].m_pNext
        .endw
            
        mov m_bBhSingStep,0
        mov @dwResult,DBG_CONTINUE

    .endif
    

;是否使用了trace脚本
.if m_bTraceCmd == 1
    invoke ShowAsmInfo
    ;判断是否停止
    mov ebx,@pAddr
        .if ebx>=g_dwEndTraceAddr
            mov m_bTraceCmd,0
            ;trace脚本停止
            
            .if m_hTraceFile!=0     
                invoke CloseHandle,m_hTraceFile ;关闭文件句柄
            .endif

         invoke InputCommand,0
            mov eax,DBG_CONTINUE
            ret
        .else
            invoke OnPCommand
            mov eax,DBG_CONTINUE
            ret
        .endif
    .endif

;单步
.if m_bSingStepCmd == 1
    mov m_bSingStepCmd,0
    invoke ShowAsmInfo
    invoke InputCommand,0
    mov @dwResult,DBG_CONTINUE
.endif
    
    ;判断是否命中硬件断点   
    mov esi, g_BhLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBhCommand
        
        mov ebx,[eax].m_dwAddr
        .if ebx==@pAddr
            ;命中硬件断点
            mov ebx,[eax].m_btType
            .if ebx==0 ;执行断点
                mov m_bBhSingStep,1 
                mov ebx,@index
                mov g_nIndexBh,ebx;取索引序号
                invoke SetBhZero0,g_nIndexBh  ;恢复dr7 0
                invoke SetTFAndDecEip,0 ;设置单步标志
                invoke ShowAsmInfo
                invoke InputCommand,0              
                mov eax,DBG_CONTINUE
                ret  
            .endif   

        
        .else ;命中访问断点
            mov @ctx.iDr6,0
            invoke SetThreadContext,m_hThread,addr @ctx
            invoke ShowAsmInfo
            invoke InputCommand,0
            mov eax,DBG_CONTINUE
            ret
        .endif
        
        inc @index     
        assume eax:nothing     
        mov esi, [esi].m_pNext
        
    .endw
    
    mov eax,@dwResult
    ret
OnSingleStep endp
;------------------触发断点异常-------
OnBreakPoint Proc uses ecx edx ebx esi edi
    LOCAL @TempBpAddr:DWORD
    LOCAL @TempBpCode:BYTE
    LOCAL @pAddr:DWORD

    mov @pAddr,0
    invoke crt_memcpy,addr @pAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof @pAddr
    
    mov m_bInputCommand,0
    
    
    mov ebx,TempBp.m_dwAddr 
    mov @TempBpAddr,ebx
    mov cl,TempBp.m_btOldCode    
    mov @TempBpCode,cl
    ;判断是否是临时断点
    .if ebx==@pAddr
        invoke OnResumeCode,@TempBpAddr,@TempBpCode
        
        mov TempBp.m_dwAddr,0
        mov TempBp.m_btOldCode,0
        mov m_bInputCommand,1
        invoke DecEip
    .endif
    
    ;命中int3断点
    mov esi, g_BpLst
    assume esi:ptr Node

     .while esi != NULL 
        mov eax,[esi].m_pUserData
        assume eax:ptr tagBpCommand
        mov ebx,[eax].m_dwAddr
        .if ebx==@pAddr
            mov ebx,[eax].m_dwAddr
            mov cl,[eax].m_btOldCode
            
            invoke OnResumeCode,ebx,cl ;恢复代码
            invoke SetTFAndDecEip,1 ;设置单步eip-1
            
            mov eax,[esi].m_pUserData
            assume eax:ptr tagBpCommand
            
            mov [eax].m_bReset,1  ;开启单步标志            
            mov m_bInputCommand,1
        .endif

        assume eax:nothing
        mov esi, [esi].m_pNext
    .endw
    
    
    ;断步配合   
    .if m_bInputCommand
        invoke ShowAsmInfo
        
        ;是否使用了trace脚本
        .if m_bTraceCmd==1
            invoke OnPCommand
            mov eax,DBG_CONTINUE
            ret
        .endif
        
        invoke InputCommand,0   
          
    .endif
    
    mov eax,DBG_CONTINUE
    ret
OnBreakPoint endp
;------------------触发内存断点异常-------
OnAccessViolation Proc uses ecx edx ebx esi edi
    LOCAL @er:EXCEPTION_DEBUG_INFO

    LOCAL @bmAddr:DWORD
    LOCAL @bmLen:DWORD
    LOCAL @bmType:DWORD
    LOCAL @bmOldProtect:DWORD
    LOCAL @bmReSet:DWORD
    LOCAL @erAddr:DWORD
    LOCAL @erType:DWORD
    LOCAL @dwOldProct:DWORD
    
    mov @bmAddr,0
    mov @bmLen,0
    mov @bmType,0
    mov @bmOldProtect,0
    mov @bmReSet,0
    mov @erAddr,0
    mov @erType,0
    mov @dwOldProct,0
    
    invoke crt_memcpy,addr @er,offset m_de.u,sizeof @er
    ;invoke crt_memcpy,addr @erType,offset m_de.u.Exception.pExceptionRecord.ExceptionInformation.,sizeof @erAddr
    ;invoke crt_memcpy,addr @erAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionInformation[1],sizeof @erAddr
     
    lea eax,@er.pExceptionRecord.ExceptionInformation       
    mov ebx,[eax]
    mov @erType,ebx
    add eax ,4
    mov ebx ,[eax]
    mov @erAddr,ebx
     
    ;判断是否命中断点
    mov esi, g_BMLst
    assume esi:ptr Node
    .while esi != NULL 
        mov eax, [esi].m_pUserData
        assume eax:ptr tagBMCommand
        mov ebx,[eax].m_dwAddr
        mov @bmAddr,ebx
        mov ebx,[eax].m_dwLen
        mov @bmLen,ebx
        mov ebx,[eax].m_dwOldProtect
        mov @bmOldProtect,ebx
        mov ebx,[eax].m_dwType
        mov @bmType,ebx
        mov ebx,[eax].m_bReset
        mov @bmReSet,ebx
        
        ;判断类型
        mov ebx,@bmAddr
        mov ecx,ebx
        ADD ecx,@bmLen
        .if ebx<=@erAddr && @erAddr<=ecx
            mov ebx,@bmType
            .if ebx==@erType
            ;命中断点 
            invoke ShowAsmInfo
            invoke InputCommand,0
            
            invoke SetTFAndDecEip,0  
            mov @dwOldProct,0         
            invoke VirtualProtectEx,m_hProc,@bmAddr,@bmLen,@bmOldProtect,addr @dwOldProct
            .if eax==0
                invoke crt_printf,offset g_BMSetFalied 
                ret
            .endif  
            mov eax, [esi].m_pUserData
            assume eax:ptr tagBMCommand
            
            ;重设断点
            mov ebx,1
            mov [eax].m_bReset,ebx  
                                    
            .endif                      
        .endif   
        
        ;判断是否在同一分页   
        mov ebx,@erAddr
        and ebx,0fffff000h
        
        mov ecx,@bmAddr
        and ecx,0fffff000h
        
        .if ebx==ecx
            invoke SetTFAndDecEip,0  
            mov @dwOldProct,0         
            invoke VirtualProtectEx,m_hProc,@bmAddr,@bmLen,@bmOldProtect,addr @dwOldProct
            .if eax==0
                invoke crt_printf,offset g_BMSetFalied 
                ret
            .endif  
            mov eax, [esi].m_pUserData
            assume eax:ptr tagBMCommand
            
            ;重设断点
            mov ebx,1
            mov [eax].m_bReset,ebx  
        
        .endif
        assume eax:nothing     
        mov esi, [esi].m_pNext
    .endw   
    
    mov eax,DBG_CONTINUE
    ret
OnAccessViolation endp
;------------------加载DLL事件------------------------------
OnLoadDllDebugEvent proc uses ecx edx ebx esi edi
;DWORD CDebugger::OnLoadDllDEbugEvent()
;{
;	//解析DLL
;	LOAD_DLL_DEBUG_INFO& lddi = m_de.u.LoadDll;
;
;	//先读地址
;	LPVOID pAddr = 0;
;	DWORD dwBytesToRead = 0;
;	BOOL bRet = ReadProcessMemory(m_hProc, lddi.lpImageName, &pAddr, sizeof(pAddr), &dwBytesToRead);
;
;	if (!bRet)  return DBG_CONTINUE;
;	//读名称
;	if (lddi.fUnicode)
;	{
;		//unicode编码格式
;		wchar_t szPath[MAX_PATH] = {};
;		bRet = ReadProcessMemory(m_hProc, pAddr, szPath, sizeof(szPath), &dwBytesToRead);
;		if (bRet)
;		{
;			printf("[info] %ws\r\n", szPath);
;		}
;	}
;	else
;	{
;		//char
;		char szPath[MAX_PATH] = {};
;		bRet = ReadProcessMemory(m_hProc, pAddr, szPath, sizeof(szPath), &dwBytesToRead);
;		if (bRet)
;		{
;			printf("[info] %s\r\n", szPath);
;		}
;	}
;	return DBG_CONTINUE;
;}

    LOCAL @pAddr:DWORD
    LOCAL @dwBytesToRead:DWORD 
    LOCAL lddi:LOAD_DLL_DEBUG_INFO
    LOCAL szPath[MAX_PATH]:byte
    LOCAL szWPath[MAX_PATH*2]:byte
    LOCAL @DLLptr:ptr
    
    ;初始化
    mov @dwBytesToRead, 0
	mov @pAddr, 0
	invoke RtlZeroMemory, addr szWPath, MAX_PATH*2
	invoke RtlZeroMemory, addr szPath, MAX_PATH
	
    ;解析DLL
    invoke crt_memcpy,addr lddi,offset m_de.u.LoadDll,sizeof LOAD_DLL_DEBUG_INFO
    
    ;读地址
    invoke ReadProcessMemory,m_hProc,lddi.lpImageName, addr @pAddr,sizeof @pAddr,addr @dwBytesToRead
    .if eax==0
        jmp LoadDLLEnd
    .endif
    
    mov @DLLptr,offset g_szDllPath
    
    ;读名称
    .if lddi.fUnicode==1
        invoke ReadProcessMemory,m_hProc,@pAddr,addr szWPath,sizeof szWPath,addr @dwBytesToRead
        .if eax==1
            invoke crt_printf,offset g_szWCharPrintInf,addr szWPath
            
            ;保存模块信息
            ;invoke crt_memcpy @DLLptr,addr szWPath,addr @dwBytesToRead
            ;invoke wsprintf,@DLLptr,offset g_szCharPrintInf,addr szWPath                    
            ;invoke InsertLst,g_BpLst,@DLLptr        
            ;mov g_DllLst, eax  
            
            ;ADD g_DllptrIndex,48
            ;mov eax,g_DllptrIndex
            ;ADD @DLLptr,eax 
                    
        .endif
    .else
        invoke ReadProcessMemory,m_hProc,@pAddr,addr szPath,sizeof szPath,addr @dwBytesToRead
        .if eax==1
            invoke crt_printf, offset g_szCharPrintInf,addr szPath

        .endif
        
    .endif    
    
 LoadDLLEnd:
    mov eax,DBG_CONTINUE
    ret

OnLoadDllDebugEvent endp 
;------------------调试事件----------------------------
OnExceptionDebugEvent proc uses ecx edx ebx esi edi
    
;   EXCEPTION_RECORD& er = m_de.u.Exception.ExceptionRecord;//异常结构体er
;	DWORD dwResult = DBG_CONTINUE;
;
;	//每次调试事件来临都记录下当前临时地址
;	dwTempAddr = (DWORD)m_de.u.Exception.ExceptionRecord.ExceptionAddress;
;
;	//判断是不是系统断点
;	if (m_bIsSystemBp)
;	{
;		ShowAsmInfo();
;		InputCommand(); //接受输入命令
;
;		m_bIsSystemBp = FALSE;
;		return dwResult;
;	}
;
;	switch (er.ExceptionCode)
;	{
;	case EXCEPTION_BREAKPOINT:
;		dwResult = OnBreakPoint();  //断点
;		break;
;	case EXCEPTION_SINGLE_STEP:
;		dwResult = OnSingleStep();   //单步
;		break;
;	case EXCEPTION_ACCESS_VIOLATION:
;		dwResult = OnAccessViolation();
;	default:
;		break;
;	}
;
;	return dwResult;
    LOCAL @dwResult:DWORD 
    LOCAL @dwTempAddr:DWORD
    LOCAL @er:EXCEPTION_RECORD
    
    invoke crt_memcpy,addr @er,offset m_de.u.Exception.pExceptionRecord,sizeof EXCEPTION_RECORD
    mov @dwResult,DBG_CONTINUE
    ;记录下临时地址
    invoke crt_memcpy,addr g_dwTempAddr,offset m_de.u.Exception.pExceptionRecord.ExceptionAddress,sizeof m_de.u.Exception.pExceptionRecord.ExceptionAddress
    
    ;判断是不是系统断点
    .if m_bIsSystemBp
        invoke ShowAsmInfo   ;反汇编
        invoke InputCommand,0  ;接受输入命令
        
        mov m_bIsSystemBp,FALSE  
        mov eax,@dwResult
        ret
    .endif
    
    .if @er.ExceptionCode==EXCEPTION_BREAKPOINT   ;触发断点异常(0x80000003)     
        invoke OnBreakPoint
        mov @dwResult,eax
        ret
    .elseif @er.ExceptionCode==EXCEPTION_SINGLE_STEP ;触发单步异常(0x80000004)    
        invoke OnSingleStep
        mov @dwResult,eax
    .elseif @er.ExceptionCode==EXCEPTION_ACCESS_VIOLATION ;触发内存断点访问异常(0xC0000005) 
        invoke OnAccessViolation
        mov @dwResult,eax
        ret
    .endif
    mov @dwResult,eax
    ret
OnExceptionDebugEvent endp
;------------------获取PE信息----------------------
GetPeInf proc uses ecx edx ebx esi edi
    LOCAL @dwBytesToRead
    LOCAL @dwSize
       
    lea edi,m_de.u
    assume edi:ptr CREATE_PROCESS_DEBUG_INFO  
   
    mov eax,[edi].lpBaseOfImage
    mov g_dwModule,eax  ;获取模块基址
    
    ;获取Nt头  
    invoke ReadProcessMemory,m_hProc,g_dwModule ,offset g_pImgDosHdr, sizeof(IMAGE_DOS_HEADER), addr @dwBytesToRead
    
    mov ebx, [g_pImgDosHdr].e_lfanew
    ADD ebx, g_dwModule
    mov g_pImgBase,ebx
    ;获取Nt头
    invoke ReadProcessMemory,m_hProc,ebx,offset g_pImgNtHdr, sizeof(IMAGE_NT_HEADERS32), addr @dwBytesToRead
    
        
    mov eax,g_pImgBase
    ADD eax,120   
    mov g_dwSecHdrAddr,eax ;获取SecHdr首地址
          
    ;获取File头
    ADD ebx,4
    invoke ReadProcessMemory,m_hProc,ebx,offset g_pImgFileHdr, sizeof(IMAGE_FILE_HEADER), addr @dwBytesToRead
    
    ADD ebx,sizeof(IMAGE_FILE_HEADER)  
    ;获取Optional头                                 
    invoke ReadProcessMemory,m_hProc,ebx,offset g_pImgOptionalHdr, sizeof(IMAGE_OPTIONAL_HEADER), addr @dwBytesToRead
    
    ret
GetPeInf endp
;------------------RunDGLOOP---------------------
RunDbgLoop proc
	;循环等待调试事件（异常） 
;	while (WaitForDebugEvent(&m_de, INFINITE))
;	{
;		m_hThread = OpenThread(THREAD_ALL_ACCESS, FALSE, m_de.dwThreadId);
;		DWORD dwResult = DBG_CONTINUE; // 程序继续运行
;		//3）处理事件
;		switch (m_de.dwDebugEventCode)
;		{
;		case  EXCEPTION_DEBUG_EVENT:		//调试事件
; 			dwResult = OnExceptionDebugEvent();  
;			break;
;		case  CREATE_THREAD_DEBUG_EVENT:
;			break;
;		case  CREATE_PROCESS_DEBUG_EVENT:	//创建调试线程
;			break;
;		case  EXIT_THREAD_DEBUG_EVENT:
;			break;
;		case  EXIT_PROCESS_DEBUG_EVENT:
;			break;
;		case  LOAD_DLL_DEBUG_EVENT:
;			dwResult = OnLoadDllDEbugEvent();
;			break;
;		case  UNLOAD_DLL_DEBUG_EVENT:
;			break;
;		case  OUTPUT_DEBUG_STRING_EVENT:
;			break;
;		default:
;			break;
;		}
;		//提交
;		ContinueDebugEvent(m_de.dwProcessId, m_de.dwThreadId, dwResult);
;	}
;	return ;

    LOCAL @dwResult:DWORD

    .while 1
        invoke WaitForDebugEvent,offset m_de,INFINITE
        .if eax==0
            .break
        .endif
         
        invoke OpenThread,THREAD_ALL_ACCESS,FALSE,m_de.dwThreadId

        mov m_hThread,eax
        
       	mov @dwResult,DBG_EXCEPTION_NOT_HANDLED
       	
        .if m_de.dwDebugEventCode==EXCEPTION_DEBUG_EVENT
            invoke OnExceptionDebugEvent  ;调试事件
            mov @dwResult,eax          
        .elseif m_de.dwDebugEventCode==CREATE_THREAD_DEBUG_EVENT
            mov @dwResult,DBG_CONTINUE        
        .elseif m_de.dwDebugEventCode==CREATE_PROCESS_DEBUG_EVENT
            invoke GetPeInf   ;获取调试文件的PE信息
            mov @dwResult,DBG_CONTINUE
        .elseif m_de.dwDebugEventCode==EXIT_THREAD_DEBUG_EVENT
            mov @dwResult,DBG_CONTINUE
        .elseif m_de.dwDebugEventCode==EXIT_PROCESS_DEBUG_EVENT
            mov @dwResult,DBG_CONTINUE
        .elseif m_de.dwDebugEventCode==LOAD_DLL_DEBUG_EVENT
            invoke OnLoadDllDebugEvent     ;加载DLL事件
            mov @dwResult,eax
        .elseif m_de.dwDebugEventCode==UNLOAD_DLL_DEBUG_EVENT
            mov @dwResult,DBG_CONTINUE
        .elseif m_de.dwDebugEventCode==OUTPUT_DEBUG_STRING_EVENT
            mov @dwResult,DBG_CONTINUE
        .else   
                                          
        .endif
        invoke ContinueDebugEvent,m_de.dwProcessId,m_de.dwThreadId,@dwResult
        .if m_hThread
            invoke CloseHandle, m_hThread
        .endif
        
    .endw 
    
    ret
RunDbgLoop endp
; -----------------Main函数-----------------------------------
main proc
    LOCAL @szCommand[32]:BYTE
    LOCAL @szProcExe[32]:BYTE
    LOCAL @pCmd:DWORD
    LOCAL @pStrExe:DWORD
    
        mov @pCmd,0
        invoke RtlZeroMemory,addr @szCommand,32
        invoke RtlZeroMemory,addr @szProcExe,32
        
        ;初始化 
        invoke RtlZeroMemory,addr g_szScriptBuffer,1000
        mov eax,g_dwTempAddr
        mov g_dwTempAddr,0
        .while 1
            invoke crt_printf,offset g_szWss,addr g_DebugUIInput
            invoke crt_printf,offset g_szWss,addr g_DebugUIDB
            invoke crt_printf,offset g_szWss,addr g_DebugUIH
            invoke crt_printf,offset g_szWss,addr g_DebugUIQ
            
            invoke crt_gets, addr @szCommand ; 输入内容并接收参数   
            lea eax,@szCommand
            mov @pCmd,eax
            invoke SkipWhiteChar,@pCmd;跳过空格
	        mov @pCmd,eax

	        mov eax,@pCmd
	        mov al,byte ptr [eax]
	

            .if al=='q'||al=='Q'  
                invoke ExitProcess, 0        
            .elseif al=='h' ||al=='h' 
                invoke OnHCommand
            .elseif al=='D'||al=='d'
	            inc @pCmd    
	            mov eax,@pCmd
	            mov al,byte ptr [eax]
	            .if al=='e'||al=='E' ;
	                inc @pCmd
	                mov eax,@pCmd
	                mov al,byte ptr [eax]  
	                .if al=='b'||al=='B' ;
	                    inc @pCmd
	                    mov eax,@pCmd
	                    mov al,byte ptr [eax]  
	                    .if al=='u'||al=='U' ;
	                        inc @pCmd
	                        mov eax,@pCmd
	                        mov al,byte ptr [eax]
	                    	.if al=='g'||al=='G' ;
	                            inc @pCmd  
	                            invoke SkipWhiteChar,@pCmd;跳过空格
	                            mov @pCmd,eax
	                            
	                            invoke crt_memcpy,offset g_szProcExe,@pCmd,20
                                
	                            invoke StartDebug,offset g_szProcExe
	                            ;invoke StartDebug,offset g_szTextProcExe
	                            .if eax==1
	                                invoke RunDbgLoop
	                            .else
	                                invoke crt_printf,offset g_szWss,addr g_DebugCmdInputError     
	                            .endif   
	                        .endif
	                    .endif
	                .endif
	            .endif              
            .endif
            invoke crt_printf,offset g_szWss,addr g_DebugCmdError                               
                               
        .endw

		ret
			
main endp

start:
	invoke main
	invoke ExitProcess, 0

end start






