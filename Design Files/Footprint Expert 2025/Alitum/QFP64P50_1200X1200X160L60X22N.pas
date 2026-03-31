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

Procedure CreateSMDComponentPad(NewPCBLibComp : IPCB_LibComponent, Name : String, Layer : TLayer, X : Real, Y : Real, OffsetX : Real, OffsetY : Real,
                                TopShape : TShape, TopXSize : Real, TopYSize : Real, Rotation: Real, CRRatio : Real, PMExpansion : Real, SMExpansion : Real,
                                PMFromRules : Boolean, SMFromRules : Boolean);
Var
    NewPad                      : IPCB_Pad2;
    PadCache                    : TPadCache;

Begin
    NewPad := PcbServer.PCBObjectFactory(ePadObject, eNoDimension, eCreate_Default);
    NewPad.HoleSize := MMsToCoord(0);
    NewPad.Layer    := Layer;
    NewPad.TopShape := TopShape;
    if TopShape = eRoundedRectangular then
        NewPad.SetState_StackCRPctOnLayer(eTopLayer, CRRatio);
    NewPad.TopXSize := MMsToCoord(TopXSize);
    NewPad.TopYSize := MMsToCoord(TopYSize);
    NewPad.RotateBy(Rotation);
    NewPad.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
    NewPad.Name := Name;

    Padcache := NewPad.GetState_Cache;
    if (PMExpansion <> 0) or (PMFromRules = False) then
    Begin
        Padcache.PasteMaskExpansionValid   := eCacheManual;
        Padcache.PasteMaskExpansion        := MMsToCoord(PMExpansion);
    End;
    if (SMExpansion <> 0) or (SMFromRules = False) then
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

Procedure CreateComponentQFP64P50_1200X1200X160L60X22N(Zero : integer);
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

        NewPcbLibComp := CreateAComponent('QFP64P50_1200X1200X160L60X22N');
        NewPcbLibComp.Name := 'QFP64P50_1200X1200X160L60X22N';
        NewPCBLibComp.Description := 'Quad Flat Pack (QFP), 0.50 mm pitch; 64 pin, square, 16 pin X 16 pin, 10.00 mm L X 10.00 mm W X 1.60 mm H body';
        NewPCBLibComp.Height := MMsToCoord(1.6);

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

        CreateSMDComponentPad(NewPCBLibComp, '1', eTopLayer, -3.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '2', eTopLayer, -3.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '3', eTopLayer, -2.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '4', eTopLayer, -2.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '5', eTopLayer, -1.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '6', eTopLayer, -1.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '7', eTopLayer, -0.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '8', eTopLayer, -0.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '9', eTopLayer, 0.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '10', eTopLayer, 0.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '11', eTopLayer, 1.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '12', eTopLayer, 1.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '13', eTopLayer, 2.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '14', eTopLayer, 2.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '15', eTopLayer, 3.25, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '16', eTopLayer, 3.75, -5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 270, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '17', eTopLayer, 5.595, -3.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '18', eTopLayer, 5.595, -3.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '19', eTopLayer, 5.595, -2.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '20', eTopLayer, 5.595, -2.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '21', eTopLayer, 5.595, -1.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '22', eTopLayer, 5.595, -1.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '23', eTopLayer, 5.595, -0.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '24', eTopLayer, 5.595, -0.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '25', eTopLayer, 5.595, 0.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '26', eTopLayer, 5.595, 0.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '27', eTopLayer, 5.595, 1.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '28', eTopLayer, 5.595, 1.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '29', eTopLayer, 5.595, 2.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '30', eTopLayer, 5.595, 2.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '31', eTopLayer, 5.595, 3.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '32', eTopLayer, 5.595, 3.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 0, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '33', eTopLayer, 3.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '34', eTopLayer, 3.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '35', eTopLayer, 2.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '36', eTopLayer, 2.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '37', eTopLayer, 1.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '38', eTopLayer, 1.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '39', eTopLayer, 0.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '40', eTopLayer, 0.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '41', eTopLayer, -0.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '42', eTopLayer, -0.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '43', eTopLayer, -1.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '44', eTopLayer, -1.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '45', eTopLayer, -2.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '46', eTopLayer, -2.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '47', eTopLayer, -3.25, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '48', eTopLayer, -3.75, 5.595, 0, 0, eRoundedRectangular, 1.21, 0.31, 90, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '49', eTopLayer, -5.595, 3.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '50', eTopLayer, -5.595, 3.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '51', eTopLayer, -5.595, 2.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '52', eTopLayer, -5.595, 2.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '53', eTopLayer, -5.595, 1.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '54', eTopLayer, -5.595, 1.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '55', eTopLayer, -5.595, 0.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '56', eTopLayer, -5.595, 0.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '57', eTopLayer, -5.595, -0.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '58', eTopLayer, -5.595, -0.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '59', eTopLayer, -5.595, -1.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '60', eTopLayer, -5.595, -1.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '61', eTopLayer, -5.595, -2.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '62', eTopLayer, -5.595, -2.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '63', eTopLayer, -5.595, -3.25, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);
        CreateSMDComponentPad(NewPCBLibComp, '64', eTopLayer, -5.595, -3.75, 0, 0, eRoundedRectangular, 1.21, 0.31, 180, 51.61, 0, 0, True, True);

        CreateComponentTrack(NewPCBLibComp, -3.86, -5.4, -3.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, -5.4, -3.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, -6, -3.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, -6, -3.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, -5.4, -3.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, -5.4, -3.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, -6, -3.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, -6, -3.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, -5.4, -2.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, -5.4, -2.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, -6, -2.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, -6, -2.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, -5.4, -2.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, -5.4, -2.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, -6, -2.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, -6, -2.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, -5.4, -1.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, -5.4, -1.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, -6, -1.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, -6, -1.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, -5.4, -1.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, -5.4, -1.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, -6, -1.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, -6, -1.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, -5.4, -0.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, -5.4, -0.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, -6, -0.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, -6, -0.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, -5.4, -0.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, -5.4, -0.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, -6, -0.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, -6, -0.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, -5.4, 0.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, -5.4, 0.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, -6, 0.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, -6, 0.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, -5.4, 0.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, -5.4, 0.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, -6, 0.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, -6, 0.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, -5.4, 1.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, -5.4, 1.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, -6, 1.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, -6, 1.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, -5.4, 1.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, -5.4, 1.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, -6, 1.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, -6, 1.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, -5.4, 2.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, -5.4, 2.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, -6, 2.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, -6, 2.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, -5.4, 2.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, -5.4, 2.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, -6, 2.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, -6, 2.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, -5.4, 3.36, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, -5.4, 3.36, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, -6, 3.14, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, -6, 3.14, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, -5.4, 3.86, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, -5.4, 3.86, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, -6, 3.64, -6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, -6, 3.64, -5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -3.86, 5.4, -3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -3.64, 6, -3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -3.64, 6, -3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -3.86, 5.4, -3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -3.36, 5.4, -3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -3.14, 6, -3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -3.14, 6, -3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -3.36, 5.4, -3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -2.86, 5.4, -2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -2.64, 6, -2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -2.64, 6, -2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -2.86, 5.4, -2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -2.36, 5.4, -2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -2.14, 6, -2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -2.14, 6, -2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -2.36, 5.4, -2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -1.86, 5.4, -1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -1.64, 6, -1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -1.64, 6, -1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -1.86, 5.4, -1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -1.36, 5.4, -1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -1.14, 6, -1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -1.14, 6, -1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -1.36, 5.4, -1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -0.86, 5.4, -0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -0.64, 6, -0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -0.64, 6, -0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -0.86, 5.4, -0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -0.36, 5.4, -0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, -0.14, 6, -0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -0.14, 6, -0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, -0.36, 5.4, -0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 0.14, 5.4, 0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 0.36, 6, 0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 0.36, 6, 0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 0.14, 5.4, 0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 0.64, 5.4, 0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 0.86, 6, 0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 0.86, 6, 0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 0.64, 5.4, 0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 1.14, 5.4, 1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 1.36, 6, 1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 1.36, 6, 1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 1.14, 5.4, 1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 1.64, 5.4, 1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 1.86, 6, 1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 1.86, 6, 1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 1.64, 5.4, 1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 2.14, 5.4, 2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 2.36, 6, 2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 2.36, 6, 2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 2.14, 5.4, 2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 2.64, 5.4, 2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 2.86, 6, 2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 2.86, 6, 2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 2.64, 5.4, 2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 3.14, 5.4, 3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 3.36, 6, 3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 3.36, 6, 3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 3.14, 5.4, 3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 3.64, 5.4, 3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5.4, 3.86, 6, 3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 3.86, 6, 3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 6, 3.64, 5.4, 3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, 5.4, 3.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, 5.4, 3.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.64, 6, 3.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.86, 6, 3.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, 5.4, 3.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, 5.4, 3.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.14, 6, 3.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 3.36, 6, 3.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, 5.4, 2.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, 5.4, 2.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.64, 6, 2.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.86, 6, 2.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, 5.4, 2.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, 5.4, 2.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.14, 6, 2.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 2.36, 6, 2.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, 5.4, 1.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, 5.4, 1.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.64, 6, 1.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.86, 6, 1.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, 5.4, 1.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, 5.4, 1.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.14, 6, 1.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 1.36, 6, 1.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, 5.4, 0.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, 5.4, 0.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.64, 6, 0.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.86, 6, 0.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, 5.4, 0.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, 5.4, 0.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.14, 6, 0.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 0.36, 6, 0.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, 5.4, -0.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, 5.4, -0.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.36, 6, -0.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.14, 6, -0.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, 5.4, -0.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, 5.4, -0.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.86, 6, -0.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -0.64, 6, -0.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, 5.4, -1.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, 5.4, -1.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.36, 6, -1.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.14, 6, -1.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, 5.4, -1.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, 5.4, -1.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.86, 6, -1.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -1.64, 6, -1.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, 5.4, -2.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, 5.4, -2.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.36, 6, -2.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.14, 6, -2.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, 5.4, -2.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, 5.4, -2.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.86, 6, -2.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -2.64, 6, -2.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, 5.4, -3.36, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, 5.4, -3.36, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.36, 6, -3.14, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.14, 6, -3.14, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, 5.4, -3.86, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, 5.4, -3.86, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.86, 6, -3.64, 6, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -3.64, 6, -3.64, 5.4, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 3.86, -5.4, 3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 3.64, -6, 3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 3.64, -6, 3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 3.86, -5.4, 3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 3.36, -5.4, 3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 3.14, -6, 3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 3.14, -6, 3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 3.36, -5.4, 3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 2.86, -5.4, 2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 2.64, -6, 2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 2.64, -6, 2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 2.86, -5.4, 2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 2.36, -5.4, 2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 2.14, -6, 2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 2.14, -6, 2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 2.36, -5.4, 2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 1.86, -5.4, 1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 1.64, -6, 1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 1.64, -6, 1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 1.86, -5.4, 1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 1.36, -5.4, 1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 1.14, -6, 1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 1.14, -6, 1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 1.36, -5.4, 1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 0.86, -5.4, 0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 0.64, -6, 0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 0.64, -6, 0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 0.86, -5.4, 0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 0.36, -5.4, 0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, 0.14, -6, 0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 0.14, -6, 0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, 0.36, -5.4, 0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -0.14, -5.4, -0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -0.36, -6, -0.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -0.36, -6, -0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -0.14, -5.4, -0.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -0.64, -5.4, -0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -0.86, -6, -0.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -0.86, -6, -0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -0.64, -5.4, -0.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -1.14, -5.4, -1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -1.36, -6, -1.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -1.36, -6, -1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -1.14, -5.4, -1.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -1.64, -5.4, -1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -1.86, -6, -1.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -1.86, -6, -1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -1.64, -5.4, -1.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -2.14, -5.4, -2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -2.36, -6, -2.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -2.36, -6, -2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -2.14, -5.4, -2.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -2.64, -5.4, -2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -2.86, -6, -2.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -2.86, -6, -2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -2.64, -5.4, -2.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -3.14, -5.4, -3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -3.36, -6, -3.36, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -3.36, -6, -3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -3.14, -5.4, -3.14, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -3.64, -5.4, -3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5.4, -3.86, -6, -3.86, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -3.86, -6, -3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -6, -3.64, -5.4, -3.64, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5, -5, -5, 5, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, -5, 5, 5, 5, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5, 5, 5, -5, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentTrack(NewPCBLibComp, 5, -5, -5, -5, ILayer.MechanicalLayer(21), 0.025, False);
        CreateComponentArc(NewPCBLibComp, -4.305, -5.95, 0.125, 0, 360, eTopOverlay, 0.25, False);
        CreateComponentTrack(NewPCBLibComp, 0, 0.35, 0, -0.35, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -0.35, 0, 0.35, 0, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentArc(NewPCBLibComp, 0, 0, 0.25, 0, 360, ILayer.MechanicalLayer(17), 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5, -5, -4, -5, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -4, -5, -5, -4, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -5, -4, -5, 5, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -5, 5, 5, 5, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, 5, 5, 5, -5, eMechanical9, 0.12, False);
        CreateComponentTrack(NewPCBLibComp, -4.13, -5.075, -5.075, -5.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -5.075, -5.075, -5.075, -4.13, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 4.13, -5.075, 5.075, -5.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 5.075, -5.075, 5.075, -4.13, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 4.13, 5.075, 5.075, 5.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 5.075, 5.075, 5.075, 4.13, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -4.13, 5.075, -5.075, 5.075, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, -5.075, 5.075, -5.075, 4.13, eTopOverlay, 0.15, False);
        CreateComponentTrack(NewPCBLibComp, 5.2, -5.2, 5.2, -4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.2, -4.105, 6.4, -4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.4, -4.105, 6.4, 4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 6.4, 4.105, 5.2, 4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.2, 4.105, 5.2, 5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 5.2, 5.2, 4.105, 5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.105, 5.2, 4.105, 6.4, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.105, 6.4, -4.105, 6.4, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.105, 6.4, -4.105, 5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.105, 5.2, -5.2, 5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.2, 5.2, -5.2, 4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.2, 4.105, -6.4, 4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.4, 4.105, -6.4, -4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -6.4, -4.105, -5.2, -4.105, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.2, -4.105, -5.2, -5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -5.2, -5.2, -4.105, -5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.105, -5.2, -4.105, -6.4, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, -4.105, -6.4, 4.105, -6.4, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.105, -6.4, 4.105, -5.2, eMechanical15, 0.05, False);
        CreateComponentTrack(NewPCBLibComp, 4.105, -5.2, 5.2, -5.2, eMechanical15, 0.05, False);

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

    CreateComponentQFP64P50_1200X1200X160L60X22N(0);

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
