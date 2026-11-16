package body Recursion is

   Pi : constant Float := 3.14159265;

   Frame      : Natural := 1;
   Branches   : Natural := 5;
   Draw_Depth : Natural := 5;
   Terms  : Natural := 0;
   Status : Status_Kind := Ok;

   Seg_N : Natural := 0;
   Segs : array (0 .. Max_Segments * 5 - 1) of Integer := (others => 0);

   Dot_N : Natural := 0;
   Dots : array (0 .. Max_Dots * 5 - 1) of Integer := (others => 0);

   Value_At : constant := 0;
   Older_At : constant := Max_Digits;
   Newer_At : constant := Max_Digits * 2;
   Places : array (0 .. Max_Digits * 3 - 1) of Integer := (others => 0);
   Value_Len, Older_Len, Newer_Len : Natural := 0;
   Unit_Exp : Natural := 0;

   Work_X1, Work_Y1, Work_X2, Work_Y2 :
     array (0 .. Max_Segments - 1) of Float := (others => 0.0);
   Work_Level : array (0 .. Max_Segments - 1) of Integer := (others => 0);
   Work_N : Natural := 0;

   Meta : array (1 .. 14) of Integer := (others => 0);
   Fit_Scale, Fit_Ox, Fit_Oy : Float := 1.0;
   Focus_X, Focus_Y : Integer := 500;

   Wobble : constant array (0 .. 6) of Float :=
     (0.0, 1.6, -0.9, 1.2, -0.4, 0.8, -1.1);

   function Frame_Depth return Natural is (Frame);
   function Tree_Depth return Natural is (Branches);
   function Tree_Visible return Natural is (Draw_Depth);
   function Segment_Count return Natural is (Seg_N);
   function Segment_X1 (Index : Natural) return Integer is (Segs (Index * 5));
   function Segment_Y1 (Index : Natural) return Integer is (Segs (Index * 5 + 1));
   function Segment_X2 (Index : Natural) return Integer is (Segs (Index * 5 + 2));
   function Segment_Y2 (Index : Natural) return Integer is (Segs (Index * 5 + 3));
   function Segment_Level (Index : Natural) return Integer is (Segs (Index * 5 + 4));
   function Rabbit_Terms return Natural is (Terms);
   function Dot_Count return Natural is (Dot_N);
   function Dot_X (Index : Natural) return Integer is (Dots (Index * 5));
   function Dot_Y (Index : Natural) return Integer is (Dots (Index * 5 + 1));
   function Dot_R (Index : Natural) return Integer is (Dots (Index * 5 + 2));
   function Dot_Color (Index : Natural) return Integer is (Dots (Index * 5 + 3));
   function Dot_Pile (Index : Natural) return Integer is (Dots (Index * 5 + 4));
   function Last_Status return Status_Kind is (Status);

   function Code (Item : Status_Kind) return Integer is
   begin
      case Item is
         when Ok =>
            return 0;
         when At_Bottom =>
            return 2;
         when At_Top =>
            return 3;
         when Full =>
            return 4;
      end case;
   end Code;

   procedure Publish is
   begin
      Meta (1) := Frame;
      Meta (2) := Depth_Ceiling;
      Meta (3) := Branches;
      Meta (4) := Seg_N;
      Meta (5) := Terms;
      Meta (6) := Value_Len;
      Meta (7) := Older_Len;
      Meta (8) := Newer_Len;
      Meta (9) := Dot_N;
      Meta (10) := Code (Status);
      Meta (11) := Draw_Depth;
      Meta (12) := Unit_Exp;
      Meta (13) := Focus_X;
      Meta (14) := Focus_Y;
   end Publish;

   procedure Sin_Cos (Radians : Float; Sine, Cosine : out Float) is
      Two_Pi : constant Float := 2.0 * Pi;
      X      : Float := Radians;
      X2     : Float;
      Term   : Float;
      Sum    : Float;
   begin
      while X > Pi loop
         X := X - Two_Pi;
      end loop;
      while X < -Pi loop
         X := X + Two_Pi;
      end loop;
      X2 := X * X;
      Term := X;
      Sum := X;
      for K in 1 .. 8 loop
         Term := -Term * X2 / Float ((2 * K) * (2 * K + 1));
         Sum := Sum + Term;
      end loop;
      Sine := Sum;
      Term := 1.0;
      Sum := 1.0;
      for K in 1 .. 8 loop
         Term := -Term * X2 / Float ((2 * K - 1) * (2 * K));
         Sum := Sum + Term;
      end loop;
      Cosine := Sum;
   end Sin_Cos;

   procedure Branch
     (X, Y, Angle, Length : Float;
      Level, Base : Natural;
      Factor : Float)
   is
      Sine, Cosine, X2, Y2 : Float;
      Spread, Next : Float;
   begin
      Sin_Cos (Angle, Sine, Cosine);
      X2 := X + Cosine * Length;
      Y2 := Y + Sine * Length;
      Work_X1 (Work_N) := X;
      Work_Y1 (Work_N) := Y;
      Work_X2 (Work_N) := X2;
      Work_Y2 (Work_N) := Y2;
      Work_Level (Work_N) := Level;
      Work_N := Work_N + 1;
      if Level = Draw_Depth then
         return;
      end if;
      Spread := (22.0 + Wobble ((Base + Level) mod 7)) * Factor * Pi / 180.0;
      Next := (if Level = 0 then 0.85 else Length * 0.66);
      Branch (X2, Y2, Angle + Spread, Next, Level + 1, Base, Factor * 0.97);
      Branch (X2, Y2, Angle - Spread, Next, Level + 1, Base, Factor * 0.97);
   end Branch;

   procedure Fit_Tree is
      Min_X, Max_X, Min_Y, Max_Y : Float;
      Span, Scale, Offset_X, Offset_Y : Float;
   begin
      Min_X := Work_X1 (0);
      Max_X := Work_X1 (0);
      Min_Y := Work_Y1 (0);
      Max_Y := Work_Y1 (0);
      for I in 0 .. Work_N - 1 loop
         Min_X := Float'Min (Min_X, Float'Min (Work_X1 (I), Work_X2 (I)));
         Max_X := Float'Max (Max_X, Float'Max (Work_X1 (I), Work_X2 (I)));
         Min_Y := Float'Min (Min_Y, Float'Min (Work_Y1 (I), Work_Y2 (I)));
         Max_Y := Float'Max (Max_Y, Float'Max (Work_Y1 (I), Work_Y2 (I)));
      end loop;
      if Max_X - Min_X < 0.8 then
         Min_X := Min_X - 0.4;
         Max_X := Max_X + 0.4;
      end if;
      Span := Float'Min (840.0 / (Max_X - Min_X), 840.0 / (Max_Y - Min_Y));
      Scale := Span;
      Offset_X := 500.0 - (Min_X + Max_X) * 0.5 * Scale;
      --  The trunk base sits about 8% up from the bottom of the frame.
      Offset_Y := 80.0 - Min_Y * Scale;
      Fit_Scale := Scale;
      Fit_Ox := Offset_X;
      Fit_Oy := Offset_Y;
      Seg_N := Work_N;
      for I in 0 .. Work_N - 1 loop
         Segs (I * 5) := Integer (Work_X1 (I) * Scale + Offset_X);
         Segs (I * 5 + 1) := Integer (Work_Y1 (I) * Scale + Offset_Y);
         Segs (I * 5 + 2) := Integer (Work_X2 (I) * Scale + Offset_X);
         Segs (I * 5 + 3) := Integer (Work_Y2 (I) * Scale + Offset_Y);
         Segs (I * 5 + 4) := Work_Level (I);
      end loop;
   end Fit_Tree;

   procedure Remember_Fit (Min_X, Max_X, Min_Y, Max_Y : Float) is
      Span : Float;
   begin
      Span := Float'Min (840.0 / (Max_X - Min_X), 840.0 / (Max_Y - Min_Y));
      Fit_Scale := Span;
      Fit_Ox := 500.0 - (Min_X + Max_X) * 0.5 * Span;
      Fit_Oy := 80.0 - Min_Y * Span;
   end Remember_Fit;

   procedure Measure
     (X, Y, Angle, Length : Float;
      Level : Natural;
      Factor : Float;
      Min_X, Max_X, Min_Y, Max_Y : in out Float)
   is
      Sine, Cosine, X2, Y2, Spread, Next : Float;
   begin
      Sin_Cos (Angle, Sine, Cosine);
      X2 := X + Cosine * Length;
      Y2 := Y + Sine * Length;
      Min_X := Float'Min (Min_X, Float'Min (X, X2));
      Max_X := Float'Max (Max_X, Float'Max (X, X2));
      Min_Y := Float'Min (Min_Y, Float'Min (Y, Y2));
      Max_Y := Float'Max (Max_Y, Float'Max (Y, Y2));
      if Level = Visible_Cap then
         return;
      end if;
      Spread := (22.0 + Wobble (Level mod 7)) * Factor * Pi / 180.0;
      Next := (if Level = 0 then 0.85 else Length * 0.66);
      Measure (X2, Y2, Angle + Spread, Next, Level + 1, Factor * 0.97,
               Min_X, Max_X, Min_Y, Max_Y);
      Measure (X2, Y2, Angle - Spread, Next, Level + 1, Factor * 0.97,
               Min_X, Max_X, Min_Y, Max_Y);
   end Measure;

   procedure Lock_Fit is
      Min_X, Max_X, Min_Y, Max_Y : Float;
   begin
      Min_X := 0.0;
      Max_X := 0.0;
      Min_Y := 0.0;
      Max_Y := 0.0;
      Measure (0.0, 0.0, Pi / 2.0, 0.38, 0, 1.0, Min_X, Max_X, Min_Y, Max_Y);
      if Max_X - Min_X < 0.8 then
         Min_X := Min_X - 0.4;
         Max_X := Max_X + 0.4;
      end if;
      Remember_Fit (Min_X, Max_X, Min_Y, Max_Y);
   end Lock_Fit;

   procedure Map_Screen (X, Y : Float; SX, SY : out Integer; Half, Min_X, Min_Y : Float) is
      T : Float;
   begin
      T := (X - Min_X) / (2.0 * Half) * 1000.0;
      if T < -4000.0 then
         T := -4000.0;
      elsif T > 5000.0 then
         T := 5000.0;
      end if;
      SX := Integer (T);
      T := (Y - Min_Y) / (2.0 * Half) * 1000.0;
      if T < -4000.0 then
         T := -4000.0;
      elsif T > 5000.0 then
         T := 5000.0;
      end if;
      SY := Integer (T);
   end Map_Screen;

   procedure Grow_Zoom (Zoom_Steps : Natural) is
      Half, Spread, Next, Sine, Cosine : Float;
      X, Y, Angle, Length, Factor : Float;
      Level : Natural;
      Start_X, Start_Y, End_X, End_Y : Float;
      Aim_X, Aim_Y, Cam_Min_X, Cam_Min_Y : Float;

      function Fitted_X (Value : Float) return Float is (Value * Fit_Scale + Fit_Ox);
      function Fitted_Y (Value : Float) return Float is (Value * Fit_Scale + Fit_Oy);

      function Near_Camera (WX, WY, Reach : Float) return Boolean is
         FX : constant Float := Fitted_X (WX);
         FY : constant Float := Fitted_Y (WY);
         Pad : constant Float := Reach * Fit_Scale + Half * 0.35;
      begin
         return FX + Pad >= Aim_X - Half
           and then FX - Pad <= Aim_X + Half
           and then FY + Pad >= Aim_Y - Half
           and then FY - Pad <= Aim_Y + Half;
      end Near_Camera;

      function Seen (X1, Y1, X2, Y2 : Float) return Boolean is
         A : constant Float := Fitted_X (X1);
         B : constant Float := Fitted_Y (Y1);
         C : constant Float := Fitted_X (X2);
         D : constant Float := Fitted_Y (Y2);
         Pad : constant Float := Half * 0.2;
      begin
         return Float'Max (A, C) >= Aim_X - Half - Pad
           and then Float'Min (A, C) <= Aim_X + Half + Pad
           and then Float'Max (B, D) >= Aim_Y - Half - Pad
           and then Float'Min (B, D) <= Aim_Y + Half + Pad;
      end Seen;

      procedure Emit
        (WX, WY, Heading, Span, Weight : Float;
         Depth : Natural)
      is
         EX, EY : Float;
         S1, S2, E1, E2 : Integer;
         Child, Reach, Child_Len : Float;
      begin
         Sin_Cos (Heading, Sine, Cosine);
         EX := WX + Cosine * Span;
         EY := WY + Sine * Span;
         if Work_N < Max_Segments and then Seen (WX, WY, EX, EY) then
            Map_Screen (Fitted_X (WX), Fitted_Y (WY), S1, S2, Half, Cam_Min_X, Cam_Min_Y);
            Map_Screen (Fitted_X (EX), Fitted_Y (EY), E1, E2, Half, Cam_Min_X, Cam_Min_Y);
            Work_X1 (Work_N) := Float (S1);
            Work_Y1 (Work_N) := Float (S2);
            Work_X2 (Work_N) := Float (E1);
            Work_Y2 (Work_N) := Float (E2);
            Work_Level (Work_N) := Depth;
            Work_N := Work_N + 1;
         end if;
         if Depth = Branches then
            return;
         end if;
         Reach := (if Depth = 0 then 0.85 else Span * 0.66) / 0.28;
         if not Near_Camera (EX, EY, Reach) then
            return;
         end if;
         Child := (22.0 + Wobble (Depth mod 7)) * Weight * Pi / 180.0;
         Child_Len := (if Depth = 0 then 0.85 else Span * 0.66);
         Emit (EX, EY, Heading + Child, Child_Len, Weight * 0.97, Depth + 1);
         Emit (EX, EY, Heading - Child, Child_Len, Weight * 0.97, Depth + 1);
      end Emit;
   begin
      X := 0.0;
      Y := 0.0;
      Angle := Pi / 2.0;
      Length := 0.38;
      Factor := 1.0;
      Level := 0;
      Sin_Cos (Angle, Sine, Cosine);
      End_X := X + Cosine * Length;
      End_Y := Y + Sine * Length;
      Start_X := X;
      Start_Y := Y;
      X := End_X;
      Y := End_Y;
      for Step in 1 .. Zoom_Steps loop
         Spread := (22.0 + Wobble (Level mod 7)) * Factor * Pi / 180.0;
         Next := (if Level = 0 then 0.85 else Length * 0.66);
         Angle := Angle - Spread;
         Factor := Factor * 0.97;
         Length := Next;
         Level := Level + 1;
         Start_X := X;
         Start_Y := Y;
         Sin_Cos (Angle, Sine, Cosine);
         X := X + Cosine * Length;
         Y := Y + Sine * Length;
      end loop;
      End_X := X;
      End_Y := Y;
      --  About 1.6 times closer each tap: the window tracks the branch,
      --  which itself shortens by about two thirds.
      Half := Length * Fit_Scale * 1.35;
      if Half < 8.0 then
         Half := 8.0;
      end if;
      Aim_X := Fitted_X (End_X) - (End_X - Start_X) / Length * Half * 0.42;
      Aim_Y := Fitted_Y (End_Y) - (End_Y - Start_Y) / Length * Half * 0.42;
      Cam_Min_X := Aim_X - Half;
      Cam_Min_Y := Aim_Y - Half;
      Draw_Depth := Zoom_Steps;
      Work_N := 0;
      Emit (0.0, 0.0, Pi / 2.0, 0.38, 1.0, 0);
      if Work_N = 0 then
         Emit (Start_X, Start_Y, Angle, Length, Factor, Level);
      end if;
      Seg_N := Work_N;
      for I in 0 .. Work_N - 1 loop
         Segs (I * 5) := Integer (Work_X1 (I));
         Segs (I * 5 + 1) := Integer (Work_Y1 (I));
         Segs (I * 5 + 2) := Integer (Work_X2 (I));
         Segs (I * 5 + 3) := Integer (Work_Y2 (I));
         Segs (I * 5 + 4) := Work_Level (I);
      end loop;
      Map_Screen (Fitted_X (End_X), Fitted_Y (End_Y), Focus_X, Focus_Y, Half, Cam_Min_X, Cam_Min_Y);
   end Grow_Zoom;

   procedure Note_Focus (Zoom_Steps : Natural) is
      X, Y, Angle, Length, Factor, Spread, Next, Sine, Cosine : Float;
      Level : Natural;
   begin
      X := 0.0;
      Y := 0.0;
      Angle := Pi / 2.0;
      Length := 0.38;
      Factor := 1.0;
      Level := 0;
      Sin_Cos (Angle, Sine, Cosine);
      X := X + Cosine * Length;
      Y := Y + Sine * Length;
      for Step in 1 .. Zoom_Steps loop
         Spread := (22.0 + Wobble (Level mod 7)) * Factor * Pi / 180.0;
         Next := (if Level = 0 then 0.85 else Length * 0.66);
         Angle := Angle - Spread;
         Factor := Factor * 0.97;
         Length := Next;
         Level := Level + 1;
         Sin_Cos (Angle, Sine, Cosine);
         X := X + Cosine * Length;
         Y := Y + Sine * Length;
      end loop;
      Focus_X := Integer (X * Fit_Scale + Fit_Ox);
      Focus_Y := Integer (Y * Fit_Scale + Fit_Oy);
   end Note_Focus;

   procedure Grow_Tree is
   begin
      Lock_Fit;
      if Branches <= Visible_Cap then
         Draw_Depth := Branches;
         Work_N := 0;
         Branch (0.0, 0.0, Pi / 2.0, 0.38, 0, 0, 1.0);
         Fit_Tree;
         Note_Focus (1);
      else
         Grow_Zoom (Branches - Visible_Cap);
      end if;
   end Grow_Tree;

   procedure Clear_Span (Start : Natural) is
   begin
      for I in Start .. Start + Max_Digits - 1 loop
         Places (I) := 0;
      end loop;
   end Clear_Span;

   procedure Write_One (Start : Natural; Len : out Natural) is
   begin
      Clear_Span (Start);
      Places (Start) := 1;
      Len := 1;
   end Write_One;

   procedure Copy_Span (From, Into, Len : Natural) is
   begin
      for I in 0 .. Max_Digits - 1 loop
         if I < Len then
            Places (Into + I) := Places (From + I);
         else
            Places (Into + I) := 0;
         end if;
      end loop;
   end Copy_Span;

   function Fits (Len : Natural) return Boolean is (Len in 1 .. 9);

   function As_Natural (Start, Len : Natural) return Natural is
      Acc : Natural := 0;
   begin
      if not Fits (Len) then
         return 0;
      end if;
      for I in reverse 0 .. Len - 1 loop
         Acc := Acc * 10 + Natural (Places (Start + I));
      end loop;
      return Acc;
   end As_Natural;

   function As_Text (Start, Len : Natural) return String is
      Text : String (1 .. Len);
   begin
      if Len = 0 then
         return "0";
      end if;
      for I in 0 .. Len - 1 loop
         Text (Len - I) := Character'Val (Character'Pos ('0') + Places (Start + I));
      end loop;
      return Text;
   end As_Text;

   function Rabbit_Value return Natural is (As_Natural (Value_At, Value_Len));
   function Rabbit_Older return Natural is (As_Natural (Older_At, Older_Len));
   function Rabbit_Newer return Natural is (As_Natural (Newer_At, Newer_Len));
   function Rabbit_Value_Text return String is (As_Text (Value_At, Value_Len));
   function Rabbit_Older_Text return String is (As_Text (Older_At, Older_Len));
   function Rabbit_Newer_Text return String is (As_Text (Newer_At, Newer_Len));
   function Rabbit_Unit_Exp return Natural is (Unit_Exp);

   function Shown (Start, Len, Exp : Natural) return Natural is
      Acc : Natural := 0;
   begin
      if Len = 0 or else Exp > Len then
         return 0;
      end if;
      if Exp = Len then
         if Places (Start + Len - 1) >= 5 then
            return 1;
         end if;
         return 0;
      end if;
      for I in reverse Exp .. Len - 1 loop
         Acc := Acc * 10 + Natural (Places (Start + I));
      end loop;
      if Exp > 0 and then Places (Start + Exp - 1) >= 5 then
         Acc := Acc + 1;
      end if;
      return Acc;
   end Shown;

   function Unit_For (Start, Len : Natural) return Natural is
      Top : Natural;
   begin
      if Len <= 1 then
         return 0;
      end if;
      if Len = 2 then
         Top := Natural (Places (Start + 1)) * 10 + Natural (Places (Start));
         if Top <= 89 then
            return 0;
         end if;
         return 1;
      end if;
      Top := Natural (Places (Start + Len - 1)) * 10
        + Natural (Places (Start + Len - 2));
      if Top <= 89 then
         return Len - 2;
      end if;
      return Len - 1;
   end Unit_For;

   procedure Add_Spans
     (A, A_Len, B, B_Len, Dest : Natural;
      Dest_Len : out Natural;
      Overflow : out Boolean)
   is
      Tmp : array (0 .. Max_Digits - 1) of Integer := (others => 0);
      Carry, Sum, N : Natural;
   begin
      Overflow := False;
      N := A_Len;
      if B_Len > N then
         N := B_Len;
      end if;
      Carry := 0;
      if N > 0 then
         for I in 0 .. N - 1 loop
         Sum := Carry;
         if I < A_Len then
            Sum := Sum + Natural (Places (A + I));
         end if;
         if I < B_Len then
            Sum := Sum + Natural (Places (B + I));
         end if;
         Tmp (I) := Integer (Sum mod 10);
            Carry := Sum / 10;
         end loop;
      end if;
      if Carry > 0 then
         if N >= Max_Digits then
            Overflow := True;
            Dest_Len := Max_Digits;
         else
            Tmp (N) := Integer (Carry);
            Dest_Len := N + 1;
         end if;
      elsif N = 0 then
         Dest_Len := 1;
      else
         Dest_Len := N;
      end if;
      for I in 0 .. Max_Digits - 1 loop
         Places (Dest + I) := Tmp (I);
      end loop;
   end Add_Spans;

   procedure Add_Dot
     (X, Y : Float;
      Radius, Color, Pile : Integer)
   is
   begin
      Dots (Dot_N * 5) := Integer (X);
      Dots (Dot_N * 5 + 1) := Integer (Y);
      Dots (Dot_N * 5 + 2) := Radius;
      Dots (Dot_N * 5 + 3) := Color;
      Dots (Dot_N * 5 + 4) := Pile;
      Dot_N := Dot_N + 1;
   end Add_Dot;

   procedure Pack_Grid
     (Count, Color, Pile : Natural;
      Left, Bottom, Cell : Float;
      Cols, Rows : Natural)
   is
      Used, Shift : Natural;
      Radius : constant Integer := Integer (Cell * 0.42);
      X, Y : Float;
   begin
      for I in 0 .. Count - 1 loop
         if I / Cols = Rows - 1 then
            Used := Count - (Rows - 1) * Cols;
            Shift := Cols - Used;
         else
            Shift := 0;
         end if;
         X := Left + (Float (I mod Cols) + 0.5 + Float (Shift) * 0.5) * Cell;
         Y := Bottom + Float (Rows) * Cell - (Float (I / Cols) + 0.5) * Cell;
         Add_Dot (X, Y, Radius, Color, Pile);
      end loop;
   end Pack_Grid;

   procedure Square_Cols (Count : Natural; Cols, Rows : out Natural) is
   begin
      Cols := 1;
      while Cols * Cols < Count loop
         Cols := Cols + 1;
      end loop;
      Rows := (Count + Cols - 1) / Cols;
   end Square_Cols;

   procedure Place_Rabbits is
      Cols_A, Rows_A, Cols_B, Rows_B : Natural;
      Cell, Small, Block, Baseline, X : Float;
      Width_SA, Width_SB, Width_BA, Width_BB : Float;
      Height_SA, Height_SB, Height_BA, Height_BB : Float;
      Plus_W : constant Float := 64.0;
      Arrow_W : constant Float := 88.0;
      Split : constant Float := 18.0;
   begin
      Dot_N := 0;
      if Terms = 1 then
         Add_Dot (500.0, 500.0, 150, 0, 2);
      elsif Terms = 2 then
         Add_Dot (500.0, 500.0, 150, 1, 2);
      else
         Unit_Exp := Unit_For (Value_At, Value_Len);
         declare
            Count_A : Natural := Shown (Older_At, Older_Len, Unit_Exp);
            Count_B : Natural := Shown (Newer_At, Newer_Len, Unit_Exp);
         begin
            if Older_Len > 0 and then Count_A = 0 then
               Count_A := 1;
            end if;
            if Newer_Len > 0 and then Count_B = 0 then
               Count_B := 1;
            end if;
            Square_Cols (Count_A, Cols_A, Rows_A);
            Square_Cols (Count_B, Cols_B, Rows_B);
         Cell := (850.0 - Plus_W - Arrow_W - Split)
           / (1.6 * Float (Cols_A + Cols_B));
         Small := Cell * 0.60;
         Height_SA := Float (Rows_A) * Small;
         Height_SB := Float (Rows_B) * Small;
         Height_BA := Float (Rows_A) * Cell;
         Height_BB := Float (Rows_B) * Cell;
         Block := Height_SA;
         if Height_SB > Block then
            Block := Height_SB;
         end if;
         if Height_BA > Block then
            Block := Height_BA;
         end if;
         if Height_BB > Block then
            Block := Height_BB;
         end if;
         if Block > 760.0 then
            Cell := Cell * 760.0 / Block;
            Small := Cell * 0.60;
            Height_SA := Float (Rows_A) * Small;
            Height_SB := Float (Rows_B) * Small;
            Height_BA := Float (Rows_A) * Cell;
            Height_BB := Float (Rows_B) * Cell;
            Block := Height_SA;
            if Height_SB > Block then
               Block := Height_SB;
            end if;
            if Height_BA > Block then
               Block := Height_BA;
            end if;
            if Height_BB > Block then
               Block := Height_BB;
            end if;
         end if;
         Width_SA := Float (Cols_A) * Small;
         Width_SB := Float (Cols_B) * Small;
         Width_BA := Float (Cols_A) * Cell;
         Width_BB := Float (Cols_B) * Cell;
         Baseline := 470.0 - Block * 0.5;
         X := (1000.0
               - (Width_SA + Plus_W + Width_SB + Arrow_W + Width_BA + Split + Width_BB))
              / 2.0;
         Pack_Grid (Count_A, 0, 0, X, Baseline, Small, Cols_A, Rows_A);
         X := X + Width_SA + Plus_W;
         Pack_Grid (Count_B, 1, 1, X, Baseline, Small, Cols_B, Rows_B);
         X := X + Width_SB + Arrow_W;
         Pack_Grid (Count_A, 0, 2, X, Baseline, Cell, Cols_A, Rows_A);
         X := X + Width_BA + Split;
         Pack_Grid (Count_B, 1, 2, X, Baseline, Cell, Cols_B, Rows_B);
         end;
      end if;
   end Place_Rabbits;

   procedure Reset_Rabbits is
   begin
      Terms := 1;
      Write_One (Value_At, Value_Len);
      Older_Len := 0;
      Newer_Len := 0;
      Clear_Span (Older_At);
      Clear_Span (Newer_At);
      Unit_Exp := 0;
      Status := Ok;
      Place_Rabbits;
      Publish;
   end Reset_Rabbits;

   procedure Reset is
   begin
      Frame := 1;
      Branches := 5;
      Status := Ok;
      Grow_Tree;
      Reset_Rabbits;
   end Reset;

   procedure Deeper is
   begin
      if Frame >= Depth_Ceiling then
         Status := At_Top;
      else
         Frame := Frame + 1;
         Status := Ok;
      end if;
      Publish;
   end Deeper;

   procedure Back is
   begin
      if Frame = 1 then
         Status := At_Bottom;
      else
         Frame := Frame - 1;
         Status := Ok;
      end if;
      Publish;
   end Back;

   procedure Set_Tree (Depth : Integer) is
   begin
      if Depth <= 0 then
         Branches := 0;
         Status := Ok;
      elsif Depth >= Depth_Ceiling then
         Branches := Depth_Ceiling;
         Status := At_Top;
      else
         Branches := Natural (Depth);
         Status := Ok;
      end if;
      Grow_Tree;
      Publish;
   end Set_Tree;

   procedure Next_Rabbit is
      Hold_Len, New_Len : Natural;
      Overflow : Boolean;
   begin
      if Terms >= Depth_Ceiling then
         Status := Full;
         Publish;
         return;
      end if;
      if Terms = 1 then
         Terms := 2;
         Write_One (Value_At, Value_Len);
         Older_Len := 0;
         Newer_Len := 0;
      elsif Terms = 2 then
         Terms := 3;
         Write_One (Older_At, Older_Len);
         Write_One (Newer_At, Newer_Len);
         Clear_Span (Value_At);
         Places (Value_At) := 2;
         Value_Len := 1;
      else
         declare
            Saved : array (0 .. Max_Digits - 1) of Integer := (others => 0);
            Saved_Len : constant Natural := Value_Len;
         begin
            for I in 0 .. Saved_Len - 1 loop
               Saved (I) := Places (Value_At + I);
            end loop;
            Add_Spans
              (Newer_At, Newer_Len, Value_At, Value_Len, Value_At,
               New_Len, Overflow);
            if Overflow then
               Status := Full;
               Publish;
               return;
            end if;
            Hold_Len := Newer_Len;
            Copy_Span (Newer_At, Older_At, Hold_Len);
            Older_Len := Hold_Len;
            Clear_Span (Newer_At);
            for I in 0 .. Saved_Len - 1 loop
               Places (Newer_At + I) := Saved (I);
            end loop;
            Newer_Len := Saved_Len;
            Value_Len := New_Len;
            Terms := Terms + 1;
         end;
      end if;
      Status := Ok;
      Place_Rabbits;
      Publish;
   end Next_Rabbit;

   function Meta_Address return System.Address is (Meta'Address);
   function Segment_Address return System.Address is (Segs'Address);
   function Dot_Address return System.Address is (Dots'Address);
   function Digit_Address return System.Address is (Places'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Deeper_Exported is
   begin
      Deeper;
   end Deeper_Exported;

   procedure Back_Exported is
   begin
      Back;
   end Back_Exported;

   procedure Tree_Exported (Depth : Integer) is
   begin
      Set_Tree (Depth);
   end Tree_Exported;

   procedure Next_Exported is
   begin
      Next_Rabbit;
   end Next_Exported;

   procedure Rabbits_Reset_Exported is
   begin
      Reset_Rabbits;
   end Rabbits_Reset_Exported;

end Recursion;
