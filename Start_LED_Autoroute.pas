{ Altium autorouter launcher - first compatibility test for Designer 26.

  Run StartLEDAutoroute with the reviewed, placed test PcbDoc active.
  Calls the documented legacy PCB:AutoRoute process, Action=Start.
  AD26 behavior is NOT runtime-tested: it may open the Situs Routing
  Strategies dialog rather than immediately begin routing. If it opens,
  choose the appropriate strategy and click Route All.
  OpenLEDAutorouteSetup is a separate optional entry point for setup only.

  Uses existing PCB nets, rules, enabled routing layers and strategy.
  Does not set trace widths, clearance, vias, or modify component placement.
  Autorouting can change existing routes according to Situs settings.
  The command scope is the entire active PCB, not just four designators.
  No auto-save and no claim of completed routing upon process return.

  Before testing:
  - Use the placed LED test PCB, with the schematic nets transferred.
  - Review width, clearance, routing layers, via rules and a closed routing
    keepout boundary. The earlier resize script changes only board shape;
    it does not create the separate keepout boundary described by Situs.
  - Run DRC and address pre-existing shorts/clearance issues.
  - Use Lock All Pre-routes in Situs if existing routing must be preserved.
  After routing: inspect Messages, remaining unrouted connections and DRC.

  With ONLY R1, R2, Q1 and D1, expect three internal connections:
    R1 -> Q1 base; Q1 collector -> D1 cathode; D1 anode -> R2.
  Single-pad VCC, CTRL and GND nets have no second endpoint to route to.
  Supply/input/ground connections require connector or testpoint pads.

  Sources:
  Altium Server Process Reference (2008), PCB AutoRoute, Action=Start/Setup:
  https://manualzilla.com/doc/7351107/dxp-panels-reference
  Current Situs workflow:
  https://www.altium.com/documentation/altium-designer/pcb/routing/situs-topological-autorouter
}



{ Progress reporting uses Messages panel; does not clear existing messages.
  Source reviewed only; not runtime-tested in Altium 26.
  Panel repaint may be delayed during busy operations. }
Var
    ARTLastStep : String;

Procedure ARTLog(Text : String);
Var
    WS : IWorkspace;
    MM : IMessagesManager;
Begin
    ARTLastStep := Text;
    { Reporting failures must not interrupt an editing transaction. }
    Try
        WS := GetWorkspace;
        If WS = Nil Then Exit;
        MM := WS.DM_MessagesManager;
        If MM = Nil Then Exit;
        MM.BeginUpdate;
        Try
            MM.AddMessage('Script', FormatDateTime('hh:nn:ss', Now) + ' ' + Text,
                          'Start_LED_Autoroute.pas', '', '', '', 3, False);
        Finally
            MM.EndUpdate;
        End;
        WS.DM_ShowMessageView;
    Except
        { Continue original operation if logging is unavailable. }
    End;
End;

Procedure ARTDialog(Text : String);
Begin
    ARTLog(Text);
    ShowMessage(Text);
End;

Function LEDRouterBoardReady : Boolean;
Var
    Board : IPCB_Board;
    It : IPCB_BoardIterator;
    Comp : IPCB_Component;
    R1Count, R2Count, Q1Count, D1Count : Integer;
    Ref : String;
Begin
    ARTLog('Checking active PCB and required components');
    Result := False;
    If PCBServer = Nil Then
    Begin
        ARTLog('STOP: PCBServer unavailable.');
        Exit;
    End;
    Board := PCBServer.GetCurrentPCBBoard;
    If Board = Nil Then
    Begin
        ARTDialog('Activate the placed LED test PcbDoc first.');
        Exit;
    End;
    If Board.IsLibrary Then
    Begin
        ARTDialog('Activate a PCB document, not a footprint library.');
        Exit;
    End;
    R1Count := 0; R2Count := 0; Q1Count := 0; D1Count := 0;
    It := Board.BoardIterator_Create;
    Try
        It.AddFilter_ObjectSet(MkSet(eComponentObject));
        It.AddFilter_LayerSet(AllLayers);
        It.AddFilter_Method(eProcessAll);
        Comp := It.FirstPCBObject;
        While Comp <> Nil Do
        Begin
            Ref := UpperCase(Comp.Name.Text);
            If Ref = 'R1' Then R1Count := R1Count + 1;
            If Ref = 'R2' Then R2Count := R2Count + 1;
            If Ref = 'Q1' Then Q1Count := Q1Count + 1;
            If Ref = 'D1' Then D1Count := D1Count + 1;
            Comp := It.NextPCBObject;
        End;
    Finally
        Board.BoardIterator_Destroy(It);
    End;
    ARTLog('Component counts: R1=' + IntToStr(R1Count) + ' R2=' + IntToStr(R2Count) + ' Q1=' + IntToStr(Q1Count) + ' D1=' + IntToStr(D1Count) + '');
    Result := (R1Count = 1) And (R2Count = 1) And
              (Q1Count = 1) And (D1Count = 1);
    If Not Result Then
        ARTDialog('Expected one each of R1, R2, Q1 and D1 on the active PCB. ' +
            'Update the designator checks if your annotation differs.');
End;

Procedure LEDRouterCommand(ActionName : String);
Begin
    If Not LEDRouterBoardReady Then
    Begin
        ARTLog('STOP: PCB readiness checks failed.');
        Exit;
    End;
    { Let the router manage its own editing transactions; do not wrap an
      interactive routing process in PCBServer.PreProcess/PostProcess. }
    ResetParameters;
    Try
        AddStringParameter('Action', ActionName);
        ARTLog('Calling PCB:AutoRoute, Action=' + ActionName + '');
        RunProcess('PCB:AutoRoute');
    Finally
        ResetParameters;
    End;
    ARTLog('Autorouter process returned; routing completion is not verified');
    { No success dialog: returning is not proof that copper was routed. }
End;

Procedure StartLEDAutorouteImpl;
Begin
    LEDRouterCommand('Start');
End;

Procedure OpenLEDAutorouteSetupImpl;
Begin
    LEDRouterCommand('Setup');
End;

Procedure StartLEDAutoroute;
Begin
    ARTLog('START: StartLEDAutoroute');
    Try
        StartLEDAutorouteImpl;
        ARTLog('END: StartLEDAutoroute returned. Review prior messages for warnings or errors.');
    Except
        ARTLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + ARTLastStep);
        Raise;
    End;
End;

Procedure OpenLEDAutorouteSetup;
Begin
    ARTLog('START: OpenLEDAutorouteSetup');
    Try
        OpenLEDAutorouteSetupImpl;
        ARTLog('END: OpenLEDAutorouteSetup returned. Review prior messages for warnings or errors.');
    Except
        ARTLog('UNHANDLED ERROR: ' + ExceptionMessage + '; previous step: ' + ARTLastStep);
        Raise;
    End;
End;
