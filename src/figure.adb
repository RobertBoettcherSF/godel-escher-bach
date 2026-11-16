package body Figure is

   H : constant Float := 0.86602540378;

   type Vec is record
      X, Y : Float;
   end record;

   Max_Join : constant := 121;
   Max_Curve : constant := 721;

   type Join_X is array (0 .. Max_Join - 1) of Float;
   type Join_Y is array (0 .. Max_Join - 1) of Float;
   type Curve_Axis is array (0 .. Max_Curve - 1) of Float;

   type Curve is record
      X, Y : Curve_Axis := (others => 0.0);
      Len  : Natural := 0;
   end record;

   type Snap is record
      Morph : Boolean := True;
      Stage : Integer := 0;
      Lit   : Integer := 0;
      Taps  : Integer := 0;
      Which : Integer := -1;
   end record;

   A_Count : constant := 14;
   S_Count : constant := 61;

   AX : constant array (0 .. A_Count - 1) of Float :=
     (0.0, 0.12, 0.24, 0.32, 0.355, 0.33, 0.27, 0.34, 0.36, 0.42,
      0.46, 0.45, 0.46, 0.5);
   AY : constant array (0 .. A_Count - 1) of Float :=
     (0.0, 0.02, 0.02, 0.0, 0.06, 0.16, 0.25, 0.22, 0.25, 0.255,
      0.20, 0.12, 0.05, 0.0);

   SY : constant array (0 .. S_Count - 1) of Float :=
     (0.000094067, -0.006778694, -0.011447380, -0.014778602,
      -0.016258851, -0.015040088, -0.010351332, -0.002127219,
      0.008364214, 0.018379711, 0.024429648, 0.023715186,
      0.015485631, 0.001423613, -0.015210515, -0.031087810,
      -0.044031363, -0.053380676, -0.059598315, -0.063605397,
      -0.066270464, -0.068193653, -0.069709133, -0.070972467,
      -0.072045137, -0.099724733, -0.110750258, -0.118022345,
      -0.122582926, -0.124748433, -0.124618740, -0.122183833,
      -0.117314235, -0.109615726, -0.097697206, -0.085005106,
      -0.101289973, -0.109625645, -0.114546917, -0.116854678,
      -0.116805278, -0.114474514, -0.109833693, -0.102720256,
      -0.092641509, -0.077674928, -0.071420059, -0.083247036,
      -0.089114119, -0.091828775, -0.092014658, -0.089874814,
      -0.085456883, -0.078703321, -0.069399133, -0.056903987,
      -0.038384559, -0.017003065, -0.012315411, -0.007081111,
      0.0);

   Max_Hist : constant := 24;
   Max_Eyes : constant := 800;

   Morph    : Boolean     := True;
   Stage    : Integer     := 0;
   Lit      : Integer     := 0;
   Taps     : Integer     := 0;
   Which    : Integer     := -1;
   Err      : Status_Kind := Ok;
   Hist     : array (1 .. Max_Hist) of Snap :=
     (others => (True, 0, 0, 0, -1));
   Hist_Len : Natural     := 0;
   Ready    : Boolean     := False;

   Curve_A, Curve_S : Curve;
   Meta      : array (1 .. 9) of Integer := (others => 0);
   Kind_Slot : array (Shape_Index) of Integer := (others => 0);
   XY        : array (0 .. Shape_Count * Points * 2 - 1) of Float :=
     (others => 0.0);
   Eye_XY : array (0 .. Max_Eyes * 2 - 1) of Float := (others => 0.0);
   Eye_Kd : array (0 .. Max_Eyes - 1) of Integer := (others => 0);
   N_Eyes : Natural := 0;
   Cursor : Natural := 0;

   function Morphing return Boolean is (Morph);
   function Uniform return Integer is (Stage);
   function Highlight return Integer is (Lit);
   function Tap_Count return Integer is (Taps);
   function Last_Shape return Integer is (Which);
   function Last_Status return Status_Kind is (Err);
   function Eye_Count return Natural is (N_Eyes);

   function Shape_Of (I, J, Side : Integer) return Shape_Index is
     (((J - J_Lo) * (I_Hi - I_Lo + 1) + (I - I_Lo)) * 2 + Side);

   function Shape_Kind (Shape : Shape_Index) return Integer is
     (Kind_Slot (Shape));

   function Point_X (Shape : Shape_Index; Index : Point_Index) return Float is
     (XY ((Shape * Points + Index) * 2));

   function Point_Y (Shape : Shape_Index; Index : Point_Index) return Float is
     (XY ((Shape * Points + Index) * 2 + 1));

   function Eye_X (Index : Natural) return Float is (Eye_XY (Index * 2));
   function Eye_Y (Index : Natural) return Float is (Eye_XY (Index * 2 + 1));
   function Eye_Kind (Index : Natural) return Integer is (Eye_Kd (Index));

   function Curve_Len (Curve_Id : Natural) return Natural is
     (if Curve_Id = 0 then Curve_A.Len else Curve_S.Len);

   function Curve_X (Curve_Id : Natural; Index : Natural) return Float is
     (if Curve_Id = 0 then Curve_A.X (Index) else Curve_S.X (Index));

   function Curve_Y (Curve_Id : Natural; Index : Natural) return Float is
     (if Curve_Id = 0 then Curve_A.Y (Index) else Curve_S.Y (Index));

   function Status_Code (Status : Status_Kind) return Integer is
   begin
      case Status is
         when Ok =>
            return 0;
         when Bad_Shape =>
            return 2;
         when Cannot_Undo =>
            return 5;
      end case;
   end Status_Code;

   function Vertex (I, J : Integer) return Vec is
     ((Float (I) + Float (J) * 0.5, Float (J) * H));

   function Stage_At (Y : Float) return Float is
      S, U : Float;
   begin
      if not Morph then
         return Float (Stage) / 100.0;
      end if;
      S := Y / (Float (Rows) * H);
      U := (S - 0.12) / 0.70;
      if U < 0.0 then
         U := 0.0;
      elsif U > 1.0 then
         U := 1.0;
      end if;
      return U * U * (3.0 - 2.0 * U);
   end Stage_At;

   function At_P (X : Join_X; Y : Join_Y; N : Natural; J : Integer) return Vec is
   begin
      if J <= 0 then
         return (X (0), Y (0));
      elsif J >= N then
         return (X (N - 1), Y (N - 1));
      else
         return (X (J - 1), Y (J - 1));
      end if;
   end At_P;

   procedure Build_Curve
     (HX  : Join_X;
      HYY : Join_Y;
      HN  : Natural;
      Into : in out Curve)
   is
      Src_X : Join_X;
      Src_Y : Join_Y;
      Nsrc  : Natural;
      Slot  : Natural := 0;
   begin
      Nsrc := HN + (HN - 1);
      for I in 0 .. HN - 1 loop
         Src_X (I) := HX (I);
         Src_Y (I) := HYY (I);
      end loop;
      for I in reverse 0 .. HN - 2 loop
         Src_X (HN + (HN - 2 - I)) := 1.0 - HX (I);
         Src_Y (HN + (HN - 2 - I)) := -HYY (I);
      end loop;
      for K in 1 .. Nsrc - 1 loop
         declare
            P0 : constant Vec := At_P (Src_X, Src_Y, Nsrc, K - 1);
            P1 : constant Vec := At_P (Src_X, Src_Y, Nsrc, K);
            P2 : constant Vec := At_P (Src_X, Src_Y, Nsrc, K + 1);
            P3 : constant Vec := At_P (Src_X, Src_Y, Nsrc, K + 2);
         begin
            for Step in 0 .. 5 loop
               declare
                  S  : constant Float := Float (Step) / 6.0;
                  S2 : constant Float := S * S;
                  S3 : constant Float := S2 * S;
                  Ax : constant Float := -P0.X + P2.X;
                  Ay : constant Float := -P0.Y + P2.Y;
                  Bx : constant Float :=
                    2.0 * P0.X - 5.0 * P1.X + 4.0 * P2.X - P3.X;
                  By : constant Float :=
                    2.0 * P0.Y - 5.0 * P1.Y + 4.0 * P2.Y - P3.Y;
                  Cx : constant Float :=
                    -P0.X + 3.0 * P1.X - 3.0 * P2.X + P3.X;
                  Cy : constant Float :=
                    -P0.Y + 3.0 * P1.Y - 3.0 * P2.Y + P3.Y;
               begin
                  Into.X (Slot) :=
                    0.5 * (2.0 * P1.X + Ax * S + Bx * S2 + Cx * S3);
                  Into.Y (Slot) :=
                    0.5 * (2.0 * P1.Y + Ay * S + By * S2 + Cy * S3);
                  Slot := Slot + 1;
               end;
            end loop;
         end;
      end loop;
      Into.X (Slot) := Src_X (Nsrc - 1);
      Into.Y (Slot) := Src_Y (Nsrc - 1);
      Into.Len := Slot + 1;
   end Build_Curve;

   procedure Build_Curves is
      JX : Join_X;
      JY : Join_Y;
   begin
      for I in 0 .. A_Count - 1 loop
         JX (I) := AX (I);
         JY (I) := AY (I);
      end loop;
      Build_Curve (JX, JY, A_Count, Curve_A);
      for I in 0 .. S_Count - 1 loop
         JX (I) := 0.5 * Float (I) / Float (S_Count - 1);
         JY (I) := SY (I);
      end loop;
      Build_Curve (JX, JY, S_Count, Curve_S);
      Ready := True;
   end Build_Curves;

   procedure Put (P : Vec) is
   begin
      XY (Cursor) := P.X;
      XY (Cursor + 1) := P.Y;
      Cursor := Cursor + 2;
   end Put;

   procedure Emit
     (From_C : Curve;
      A, B   : Vec;
      Sign   : Float;
      Mix    : Float;
      Rev    : Boolean;
      Skip   : Boolean)
   is
      D    : constant Vec := (B.X - A.X, B.Y - A.Y);
      Nrm  : constant Vec := (-D.Y * Sign, D.X * Sign);
      Last : constant Integer := From_C.Len - 1;

      function Point_At (K : Integer) return Vec is
         Lin   : constant Float := Float (K) / Float (Last);
         CX    : constant Float := From_C.X (K);
         CY    : constant Float := From_C.Y (K);
         Along : constant Float := (1.0 - Mix) * Lin + Mix * CX;
      begin
         return
           (A.X + Along * D.X + (Mix * CY) * Nrm.X,
            A.Y + Along * D.Y + (Mix * CY) * Nrm.Y);
      end Point_At;
   begin
      if Rev then
         declare
            Hi : constant Integer := (if Skip then Last - 1 else Last);
         begin
            for K in reverse 0 .. Hi loop
               Put (Point_At (K));
            end loop;
         end;
      else
         declare
            Lo : constant Integer := (if Skip then 1 else 0);
         begin
            for K in Lo .. Last loop
               Put (Point_At (K));
            end loop;
         end;
      end if;
   end Emit;

   procedure Refresh is
   begin
      if not Ready then
         Build_Curves;
      end if;
      N_Eyes := 0;
      for J in J_Lo .. J_Hi loop
         for I in I_Lo .. I_Hi loop
            declare
               Id  : constant Shape_Index := Shape_Of (I, J, 0);
               Id2 : constant Shape_Index := Shape_Of (I, J, 1);
               VA  : constant Vec := Vertex (I, J);
               VB  : constant Vec := Vertex (I + 1, J);
               VC  : constant Vec := Vertex (I, J + 1);
               VD  : constant Vec := Vertex (I + 1, J + 1);
               TA  : constant Float := Stage_At (Float (J) * H);
               TA1 : constant Float := Stage_At (Float (J + 1) * H);
               TM  : constant Float := Stage_At ((Float (J) + 0.5) * H);
               Start : Natural;
            begin
               Start := (Natural (Id) * Points) * 2;
               Cursor := Start;
               Emit (Curve_A, VA, VB, 1.0, TA, False, False);
               Emit (Curve_S, VB, VC, 1.0, TM, False, True);
               Emit (Curve_S, VA, VC, -1.0, TM, True, True);
               pragma Assert ((Cursor - Start) / 2 = Points, "up count");
               Kind_Slot (Id) := 0;

               Start := (Natural (Id2) * Points) * 2;
               Cursor := Start;
               Emit (Curve_S, VB, VD, -1.0, TM, False, False);
               Emit (Curve_A, VC, VD, 1.0, TA1, True, True);
               Emit (Curve_S, VB, VC, 1.0, TM, True, True);
               pragma Assert ((Cursor - Start) / 2 = Points, "down count");
               Kind_Slot (Id2) := 1;
            end;
         end loop;
      end loop;

      for J in J_Lo .. J_Hi + 1 loop
         declare
            T : constant Float := Stage_At (Float (J) * H);
         begin
            if T >= 0.8 then
               for I in I_Lo .. I_Hi + 1 loop
                  declare
                     P : constant Vec := Vertex (I, J);
                  begin
                     if N_Eyes + 2 <= Max_Eyes then
                        Eye_XY (N_Eyes * 2) := P.X + 0.39;
                        Eye_XY (N_Eyes * 2 + 1) := P.Y + 0.20 * T;
                        Eye_Kd (N_Eyes) := 0;
                        N_Eyes := N_Eyes + 1;
                        Eye_XY (N_Eyes * 2) := P.X + 0.61;
                        Eye_XY (N_Eyes * 2 + 1) := P.Y - 0.20 * T;
                        Eye_Kd (N_Eyes) := 1;
                        N_Eyes := N_Eyes + 1;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;

      Meta (1) := (if Morph then 1 else 0);
      Meta (2) := Stage;
      Meta (3) := Lit;
      Meta (4) := Taps;
      Meta (5) := Status_Code (Err);
      Meta (6) := Shape_Count;
      Meta (7) := Points;
      Meta (8) := Integer (N_Eyes);
      Meta (9) := Which;
   end Refresh;

   procedure Remember is
   begin
      if Hist_Len = Max_Hist then
         for I in 1 .. Max_Hist - 1 loop
            Hist (I) := Hist (I + 1);
         end loop;
         Hist_Len := Max_Hist - 1;
      end if;
      Hist_Len := Hist_Len + 1;
      Hist (Hist_Len) := (Morph, Stage, Lit, Taps, Which);
   end Remember;

   procedure Reset is
   begin
      Morph := True;
      Stage := 0;
      Lit := 0;
      Taps := 0;
      Which := -1;
      Err := Ok;
      Hist_Len := 0;
      Remember;
      Refresh;
   end Reset;

   procedure Set_Uniform (Value : Integer) is
   begin
      if Morph then
         Remember;
      end if;
      Morph := False;
      if Value < 0 then
         Stage := 0;
      elsif Value > 100 then
         Stage := 100;
      else
         Stage := Value;
      end if;
      Err := Ok;
      Refresh;
   end Set_Uniform;

   procedure Tap (Shape : Integer) is
      Kind : Integer;
   begin
      if Shape < 0 or else Shape >= Shape_Count then
         Err := Bad_Shape;
         Refresh;
         return;
      end if;
      Kind := Kind_Slot (Shape_Index (Shape));
      Which := Shape;
      if Lit = Kind + 1 then
         Lit := 0;
      else
         Lit := Kind + 1;
      end if;
      Taps := Taps + 1;
      Err := Ok;
      Remember;
      Refresh;
   end Tap;

   procedure Undo is
   begin
      if Hist_Len <= 1 then
         Err := Cannot_Undo;
         Refresh;
         return;
      end if;
      Hist_Len := Hist_Len - 1;
      Morph := Hist (Hist_Len).Morph;
      Stage := Hist (Hist_Len).Stage;
      Lit := Hist (Hist_Len).Lit;
      Taps := Hist (Hist_Len).Taps;
      Which := Hist (Hist_Len).Which;
      Err := Ok;
      Refresh;
   end Undo;

   function Exported_Shapes return Integer is (Shape_Count);
   function Meta_Address return System.Address is (Meta'Address);
   function Kind_Address return System.Address is (Kind_Slot'Address);
   function Outline_Address return System.Address is (XY'Address);
   function Eye_XY_Address return System.Address is (Eye_XY'Address);
   function Eye_Kind_Address return System.Address is (Eye_Kd'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Uniform_Exported (Value : Integer) is
   begin
      Set_Uniform (Value);
   end Uniform_Exported;

   procedure Tap_Exported (Shape : Integer) is
   begin
      Tap (Shape);
   end Tap_Exported;

   procedure Undo_Exported is
   begin
      Undo;
   end Undo_Exported;

end Figure;
