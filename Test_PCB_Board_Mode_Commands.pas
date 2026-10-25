{ Altium Designer 26 command-dispatch diagnostic. NOT runtime-tested here.
  Add this file to a Script Project. Activate PCB1.PcbDoc immediately before
  EACH test and run only one entry point at a time:

    TestBoardPlanningMode         - original RunProcess mode-switch request
    TestEditBoardShape            - original RunProcess interactive request
    TestBoardPlanningModeMessage  - same mode request via Client.SendMessage
    TestEditBoardShapeMessage     - same interactive request via SendMessage

  For the Edit Board Shape tests, manually enter Board Planning Mode first
  to isolate the interactive command from the failing mode-switch command.
  Observe the PCB after dispatch. Press Esc to exit any interactive tool;
  do not move vertices. A returned call does not prove the command worked.
  Check the Messages panel manually AFTER observing the PCB. Logging does
  not show that panel or display dialogs that could steal the PCB's focus.

  No outline/vertex access, resize code, editing transactions or saving.
  The interactive tool itself can change the shape if you edit vertices.
}

Procedure BCMLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                'Test_PCB_Board_Mode_Commands.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
    Except
        { Diagnostics must not interrupt dispatch or change editor focus. }
    End;
End;

Function BCMBoardReady : Boolean;
Var
    Board : IPCB_Board;
    Name : String;
Begin
    Result := False;
    If PCBServer = Nil Then
    Begin
        ShowMessage('PCBServer is unavailable. Activate a test .PcbDoc first.');
        Exit;
    End;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ShowMessage('No current PCB. Activate PCB1.PcbDoc and retry.');
        Exit;
    End;
    Name := Board.FileName;
    BCMLog('PCBServer document: ' + Name);
    If UpperCase(ExtractFileExt(Name)) <> '.PCBDOC' Then
    Begin
        ShowMessage('PCBServer returned "' + Name + '". Activate a .PcbDoc first.');
        Exit;
    End;
    If Client.CurrentView = Nil Then
    Begin
        ShowMessage('No current client view. Activate the PCB tab and retry.');
        Exit;
    End;
    Result := True;
End;

Procedure BCMTest(PlanningMode, UseClientMessage : Boolean);
Var
    ProcessName, Parameters, Dispatch : String;
Begin
    If Not BCMBoardReady Then Exit;
    If PlanningMode Then
    Begin
        ProcessName := 'PCB:ChangeViewLayoutStyle';
        Parameters := 'ViewLayoutStyle=BoardPlanningMode';
    End
    Else
    Begin
        ProcessName := 'PCB:EditBoardShape';
        Parameters := '';
    End;
    If UseClientMessage Then Dispatch := 'Client.SendMessage'
    Else Dispatch := 'RunProcess';
    BCMLog('CALL ' + Dispatch + ': ' + ProcessName + ' [' + Parameters + ']');
    Try
        ResetParameters;
        Try
            If UseClientMessage Then
                Client.SendMessage(ProcessName, Parameters, 255, Client.CurrentView)
            Else
            Begin
                If PlanningMode Then
                    AddStringParameter('ViewLayoutStyle', 'BoardPlanningMode');
                RunProcess(ProcessName);
            End;
        Finally
            ResetParameters;
        End;
        BCMLog('RETURN ' + Dispatch + ': ' + ProcessName +
            '. Dispatch returned only; visually verify the effect.');
    Except
        BCMLog('ERROR ' + Dispatch + ': ' + ProcessName + ': ' + ExceptionMessage);
        ShowMessage('Command test failed: ' + ExceptionMessage);
    End;
End;

Procedure TestBoardPlanningMode;
Begin
    BCMTest(True, False);
End;

Procedure TestEditBoardShape;
Begin
    BCMTest(False, False);
End;

Procedure TestBoardPlanningModeMessage;
Begin
    BCMTest(True, True);
End;

Procedure TestEditBoardShapeMessage;
Begin
    BCMTest(False, True);
End;
