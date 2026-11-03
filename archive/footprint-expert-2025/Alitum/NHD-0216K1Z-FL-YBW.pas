Var
    CurrentSCHLib : ISch_Lib;
    CurrentLib : IPCB_Library;

Function CreateAComponent(Name: String) : IPCB_LibComponent;
Var
    PrimitiveList: TInterfaceList;
    PrimitiveIterator: IPCB_GroupIterator;
    PrimitiveHandle: IPCB_Primitive;
    I:  Integer;

Begin
    // Check if footprint already in library
    Result := CurrentLib.GetComponentByName(Name);
    If Result = Nil Then
    Begin
        // Create New Component
        Result := PCBServer.CreatePCBLibComp;
        Result.Name := Name;
    End
    Else
    Begin
        // Clear existin component
        Try
            // Create List with all primitives on board
            PrimitiveList := TInterfaceList.Create;
            PrimitiveIterator := Result.GroupIterator_Create;
            PrimitiveIterator.AddFilter_ObjectSet(AllObjects);
            PrimitiveHandle := PrimitiveIterator.FirstPCBObject;
            While PrimitiveHandle <> Nil Do
            Begin
                PrimitiveList.Add(PrimitiveHandle);
                PrimitiveHandle := PrimitiveIterator.NextPCBObject;
            End;

            // Delete all primitives
            For I := 0 To PrimitiveList.Count - 1 Do
            Begin
                PrimitiveHandle := PrimitiveList.items[i];
                Result.RemovePCBObject(PrimitiveHandle);
                Result.GraphicallyInvalidate;
            End;

        Finally
            Result.GroupIterator_Destroy(PrimitiveIterator);
            PrimitiveList.Free;
        End;
    End;
End; 

Procedure CreateTHComponentPad(NewPCBLibComp : IPCB_LibComponent, Name : String, HoleType : TExtendedHoleType,
                               HoleSize : Real, HoleLength : Real, Layer : TLayer, X : Real, Y : Real,
                               OffsetX : Real, OffsetY : Real, TopShape : TShape, TopXSize : Real, TopYSize : Real,
                               InnerShape : TShape, InnerXSize : Real, InnerYSize : Real,
                               BottomShape : TShape, BottomXSize : Real, BottomYSize : Real,
                               Rotation: Real, CRRatio : Real, PMExpansion : Real, SMExpansion: Real, Plated : Boolean);
Var
    NewPad                      : IPCB_Pad2;
    PadCache                    : TPadCache;

Begin
    NewPad := PcbServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NewPad.Mode := ePadMode_LocalStack;
    NewPad.HoleType := HoleType;
    NewPad.HoleSize := MMsToCoord(HoleSize);
    if HoleLength <> 0 then
        NewPad.HoleWidth := MMsToCoord(HoleLength);
    NewPad.TopShape := TopShape;
    if TopShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eTopLayer, CRRatio);
    if BottomShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eBottomLayer, CRRatio);
    NewPad.TopXSize := MMsToCoord(TopXSize);
    NewPad.TopYSize := MMsToCoord(TopYSize);
    NewPad.MidShape := InnerShape;
    NewPad.MidXSize := MMsToCoord(InnerXSize);
    NewPad.MidYSize := MMsToCoord(InnerYSize);
    NewPad.BotShape := BottomShape;
    NewPad.BotXSize := MMsToCoord(BottomXSize);
    NewPad.BotYSize := MMsToCoord(BottomYSize);
    NewPad.SetState_XPadOffsetOnLayer(Layer, MMsToCoord(OffsetX));
    NewPad.SetState_YPadOffsetOnLayer(Layer, MMsToCoord(OffsetY));
    NewPad.RotateBy(Rotation);
    NewPad.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
    NewPad.Plated   := Plated;
    NewPad.Name := Name;

    Padcache := NewPad.GetState_Cache;
    if PMExpansion <> 0 then
    Begin
        Padcache.PasteMaskExpansionValid   := eCacheManual;
        Padcache.PasteMaskExpansion        := MMsToCoord(PMExpansion);
    End;
    if SMExpansion <> 0 then
    Begin
        Padcache.SolderMaskExpansionValid  := eCacheManual;
        Padcache.SolderMaskExpansion       := MMsToCoord(SMExpansion);
    End;
    NewPad.SetState_Cache              := Padcache;

    NewPCBLibComp.AddPCBObject(NewPad);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewPad.I_ObjectAddress);
End;

Procedure CreateComponentTrack(NewPCBLibComp : IPCB_LibComponent, X1 : Real, Y1 : Real, X2 : Real, Y2 : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewTrack                    : IPCB_Track;

Begin
    NewTrack := PcbServer.PCBObjectFactory(eTrackObject,eNoDimension,eCreate_Default);
    NewTrack.X1 := MMsToCoord(X1);
    NewTrack.Y1 := MMsToCoord(Y1);
    NewTrack.X2 := MMsToCoord(X2);
    NewTrack.Y2 := MMsToCoord(Y2);
    NewTrack.Layer := Layer;
    NewTrack.Width := MMsToCoord(LineWidth);
    NewTrack.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewTrack);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewTrack.I_ObjectAddress);
End;

Procedure CreateComponentArc(NewPCBLibComp : IPCB_LibComponent, CenterX : Real, CenterY : Real, Radius : Real, StartAngle : Real, EndAngle : Real, Layer : TLayer, LineWidth : Real, IsKeepout : Boolean);
Var
    NewArc                      : IPCB_Arc;

Begin
    NewArc := PCBServer.PCBObjectFactory(eArcObject,eNoDimension,eCreate_Default);
    NewArc.XCenter := MMsToCoord(CenterX);
    NewArc.YCenter := MMsToCoord(CenterY);
    NewArc.Radius := MMsToCoord(Radius);
    NewArc.StartAngle := StartAngle;
    NewArc.EndAngle := EndAngle;
    NewArc.Layer := Layer;
    NewArc.LineWidth := MMsToCoord(LineWidth);
    NewArc.IsKeepout := IsKeepout;
    NewPCBLibComp.AddPCBObject(NewArc);
    PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,NewArc.I_ObjectAddress);
End;

Function ReadStringFromIniFile(Section: String, Name: String, FilePath: String, IfEmpty: String) : String;
Var
    IniFile                     : TIniFile;

Begin
    result := IfEmpty;
    If FileExists(FilePath) Then
    Begin
        Try
            IniFile := TIniFile.Create(FilePath);

            Result := IniFile.ReadString(Section, Name, IfEmpty);
        Finally
            Inifile.Free;
        End;
    End;
End;

Procedure EnableMechanicalLayers(Zero : Integer);
Var
    Board                       : IPCB_Board;
    MajorADVersion              : Integer;

Begin
    Board := PCBServer.GetCurrentPCBBoard;

    MajorADVersion := StrToInt(Copy((ReadStringFromIniFile('Preference Location','Build',SpecialFolder_AltiumSystem+'\PrefFolder.ini','14')),0,2));

    If MajorADVersion >= 14 Then
    Begin
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(17)).SetState_MechLayerEnabled := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(17)).IsDisplayed[Board] := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(21)).SetState_MechLayerEnabled := true;
        Board.LayerStack_V7.LayerObject_V7(ILayer.MechanicalLayer(21)).IsDisplayed[Board] := true;
    End;

    If MajorADVersion < 14 Then
    Begin
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(17)).SetState_MechLayerEnabled := true;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(17)).IsDisplayed[Board]:=True;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(21)).SetState_MechLayerEnabled := true;
        Board.LayerStack.LayerObject_V7(ILayer.MechanicalLayer(21)).IsDisplayed[Board]:=True;
    End;
End;

Procedure DeleteFootprint(Name : String);
var
    CurrentLib      : IPCB_Library;
    del_list        : TInterfaceList;
    I               :  Integer;
    S_temp          : TString;
    Footprint       : IPCB_LibComponent;
    FootprintIterator : Integer;

Begin
    // ShowMessage('Script running');
    CurrentLib       := PCBServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('This is not a PCB library document');
        Exit;
    End;

    // store selected footprints in a TInterfacelist that are to be deleted later...
    del_list := TInterfaceList.Create;

    // For each page of library Is a footprint
    FootprintIterator := CurrentLib.LibraryIterator_Create;
    FootprintIterator.SetState_FilterAll;

    // Within each page, fetch primitives of the footprint
    // A footprint Is a IPCB_LibComponent inherited from
    // IPCB_Group which Is a container object storing primitives.
    Footprint := FootprintIterator.FirstPCBObject; // IPCB_LibComponent

    while (Footprint <> Nil) Do
    begin
        S_temp :=Footprint.Name;

        // check for specific footprint, to delete them before (0=equal string)
        If Not (CompareText(S_temp, Name)) Then
        begin
            del_list.Add(Footprint);
            //ShowMessage('selected footprint ' + Footprint.Name);
        end;
        Footprint := FootprintIterator.NextPCBObject;
    end;

    CurrentLib.LibraryIterator_Destroy(FootprintIterator);

    Try
        PCBServer.PreProcess;
        For I := 0 To del_list.Count - 1 Do
        Begin
            Footprint := del_list.items[i];
            // ShowMessage('deleted footprint ' + Footprint.Name);
            CurrentLib.RemoveComponent(Footprint);
        End;
    Finally
        PCBServer.PostProcess;
        del_list.Free;
    End;
End;

Procedure CreateComponentNHD_0216K1Z_FL_YBW(Zero : integer);
Var
    NewPCBLibComp               : IPCB_LibComponent;
    NewPad                      : IPCB_Pad2;
    NewRegion                   : IPCB_Region;
    NewContour                  : IPCB_Contour;
    STEPmodel                   : IPCB_ComponentBody;
    Model                       : IPCB_Model;
    TextObj                     : IPCB_Text;
    TextObj2                    : IPCB_Text;

Begin
    Try
        PCBServer.PreProcess;

        EnableMechanicalLayers(0);

        NewPcbLibComp := CreateAComponent('NHD-0216K1Z-FL-YBW');
        NewPcbLibComp.Name := 'NHD-0216K1Z-FL-YBW';
        NewPCBLibComp.Description := 'Optoelectronics, LCD, OLED Character and Numeric; 16 pin, 80.00 mm L X 36.00 mm W X 13.20 mm H body';
        NewPCBLibComp.Height := MMsToCoord(13.2);

        // Create text object for .Designator
        TextObj := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        TextObj.UseTTFonts := True;
        TextObj.Layer := eMechanical11;
        TextObj.Text := '.Designator';
        TextObj.Size := MMsToCoord(1.2);
        TextObj.Width := MMsToCoord(0.12);
        NewPCBLibComp.AddPCBObject(TextObj);
        PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,TextObj.I_ObjectAddress);

        // Create text object for .Designator
        TextObj2 := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        TextObj2.UseTTFonts := True;
        TextObj2.Layer := eMechanical9;
        TextObj2.Text := '.Designator';
        TextObj2.Size := MMsToCoord(2);
        TextObj2.Width := MMsToCoord(0.2);
        NewPCBLibComp.AddPCBObject(TextObj2);
        PCBServer.SendMessageToRobots(NewPCBLibComp.I_ObjectAddress,c_Broadcast,PCBM_BoardRegisteration,TextObj2.I_ObjectAddress);

        CreateTHComponentPad(NewPCBLibComp, '1', eRoundHole, 1, 0, eBottomLayer, 8, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '2', eRoundHole, 1, 0, eBottomLayer, 10.54, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '3', eRoundHole, 1, 0, eBottomLayer, 13.08, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '4', eRoundHole, 1, 0, eBottomLayer, 15.62, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '5', eRoundHole, 1, 0, eBottomLayer, 18.16, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '6', eRoundHole, 1, 0, eBottomLayer, 20.7, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '7', eRoundHole, 1, 0, eBottomLayer, 23.24, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '8', eRoundHole, 1, 0, eBottomLayer, 25.78, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '9', eRoundHole, 1, 0, eBottomLayer, 28.32, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '10', eRoundHole, 1, 0, eBottomLayer, 30.86, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '11', eRoundHole, 1, 0, eBottomLayer, 33.4, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '12', eRoundHole, 1, 0, eBottomLayer, 35.94, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '13', eRoundHole, 1, 0, eBottomLayer, 38.48, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '14', eRoundHole, 1, 0, eBottomLayer, 41.02, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '15', eRoundHole, 1, 0, eBottomLayer, 43.56, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, '16', eRoundHole, 1, 0, eBottomLayer, 46.1, 2, 0, 0, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, eRounded, 1.6, 1.6, 0, 0, -1.6, 0, True);
        CreateTHComponentPad(NewPCBLibComp, 'MH3', eRoundHole, 2.5, 0, eBottomLayer, 2.5, 2.5, 0, 0, eRounded, 1, 1, eRounded, 1, 1, eRounded, 1, 1, 0, 0, -1, 0.75, False);
        CreateTHComponentPad(NewPCBLibComp, 'MH1', eRoundHole, 2.5, 0, eBottomLayer, 2.5, 33.5, 0, 0, eRounded, 1, 1, eRounded, 1, 1, eRounded, 1, 1, 0, 0, -1, 0.75, False);
        CreateTHComponentPad(NewPCBLibComp, 'MH2', eRoundHole, 2.5, 0, eBottomLayer, 77.5, 33.5, 0, 0, eRounded, 1, 1, eRounded, 1, 1, eRounded, 1, 1, 0, 0, -1, 0.75, False);
        CreateTHComponentPad(NewPCBLibComp, 'MH4', eRoundHole, 2.5, 0, eBottomLayer, 77.5, 2.5, 0, 0, eRounded, 1, 1, eRounded, 1, 1, eRounded, 1, 1, 0, 0, -1, 0.75, False);

        CreateComponentArc(NewPCBLibComp, 2.5, 2.5, 1.725, 0, 360, eKeepOutLayer, 0.025, True);
        CreateComponentArc(NewPCBLibComp, 2.5, 33.5, 1.725, 0, 360, eKeepOutLayer, 0.025, True);
        CreateComponentArc(NewPCBLibComp, 77.5, 33.5, 1.725, 0, 360, eKeepOutLayer, 0.025, True);
        CreateComponentArc(NewPCBLibComp, 77.5, 2.5, 1.725, 0, 360, eKeepOutLayer, 0.025, True);
        CreateComponentTrack(NewPCBLibComp, 0, 0, 0, 36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0, 36, 80, 36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 80, 36, 80, 0, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 80, 0, 0, 0, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0, 0, 36, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 0, 36, 80, 36, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 80, 36, 80, 0, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 80, 0, 0, 0, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -0.075, -0.075, 80.075, -0.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 0.35, 0, -0.35, 0, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.075, -0.075, -0.075, 36.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -0.075, 36.075, 80.075, 36.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 80.075, 36.075, 80.075, -0.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -0.5, -0.5, 80.5, -0.5, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 80.5, -0.5, 80.5, 36.5, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 80.5, 36.5, -0.5, 36.5, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.5, 36.5, -0.5, -0.5, eMechanical15, 0.05, False);

        CurrentLib.RegisterComponent(NewPCBLibComp);
        CurrentLib.CurrentComponent := NewPcbLibComp;
    Finally
        PCBServer.PostProcess;
    End;

    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;

    // Code By Vincent Himpe
    TextObj.BeginModify;                                           // Let the PCBserver know we are going To modify
    TextObj.AdvanceSnapping := True;                               // turn On the advanced snapping capabilities
    TextObj.UnderlyingString := '.Designator';                     // Not strictly necessary but clean
    TextObj.TTFInvertedTextJustify := eAutoPos_CenterCenter;       // allow the text To autoposition inside the container
    TextObj.XLocation := NewpcbLibComp.x;                          // Set the text inside the container To origin Of he component
    TextObj.yLocation := NewpcbLibComp.y;
    TextObj.Snappointx := NewpcbLibComp.x;                         // Set the container itself into the origin Of the component
    TextObj.Snappointy := NewpcbLibComp.y;
    TextObj.endModify; // Let PCBserver know we are finished
    Textobj.GraphicallyInvalidate;                                 // force a graphical repaint

    TextObj2.BeginModify;
    TextObj2.AdvanceSnapping := True;
    TextObj2.UnderlyingString := '.Designator';
    TextObj2.TTFInvertedTextJustify := eAutoPos_CenterCenter;
    TextObj2.XLocation := NewpcbLibComp.x;
    TextObj2.yLocation := NewpcbLibComp.y;
    TextObj2.Snappointx := NewpcbLibComp.x;
    TextObj2.Snappointy := NewpcbLibComp.y;
    TextObj2.endModify; // Let PCBserver know we are finished
    Textobj2.GraphicallyInvalidate;
    //

    Client.SendMessage('PCB:Zoom', 'Action=All' , 255, Client.CurrentView)
End;

Procedure CreateAPCBLibrary(Zero : integer);
Var
    View     : IServerDocumentView;
    Document : IServerDocument;
    TempPCBLibComp : IPCB_LibComponent;

Begin
    If PCBServer = Nil Then
    Begin
        ShowMessage('No PCBServer present. This script inserts a footprint into an existing PCB Library that has the current focus.');
        Exit;
    End;

    CurrentLib := PcbServer.GetCurrentPCBLibrary;
    If CurrentLib = Nil Then
    Begin
        ShowMessage('You must have focus on a PCB Library in order for this script to run.');
        Exit;
    End;

    View := Client.GetCurrentView;
    Document := View.OwnerDocument;
    Document.Modified := True;

    // Create And focus a temporary component While we delete items (BugCrunch #10165)
    TempPCBLibComp := PCBServer.CreatePCBLibComp;
    TempPcbLibComp.Name := '___TemporaryComponent___';
    CurrentLib.RegisterComponent(TempPCBLibComp);
    CurrentLib.CurrentComponent := TempPcbLibComp;
    CurrentLib.Board.ViewManager_FullUpdate;

    CreateComponentNHD_0216K1Z_FL_YBW(0);

    // Delete Temporary Footprint And re-focus
    CurrentLib.RemoveComponent(TempPCBLibComp);
    CurrentLib.Board.ViewManager_UpdateLayerTabs;
    CurrentLib.Board.ViewManager_FullUpdate;
    Client.SendMessage('PCB:Zoom', 'Action=All', 255, Client.CurrentView);

    DeleteFootprint('PCBCOMPONENT_1');  // code by Randy C - Delete PCBCOMPONENT_1

End;

Procedure CreateALibrary;
Begin
    Screen.Cursor := crHourGlass;

    CreateAPCBLibrary(0);

    //  Show all used layers - code by Randy
    ResetParameters;
    AddStringParameter('SetIndex','0');
    RunProcess('PCB:ManageLayerSets');

    Screen.Cursor := crArrow;
End;

End.
