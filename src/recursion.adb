package body Recursion is

   Pi : constant Float := 3.14159265;

   Frame   : Depth_Range := 1;
   Branches : Tree_Range := 5;
   Terms   : Natural := 0;
   Value   : Natural := 0;
   Older   : Natural := 0;
   Newer   : Natural := 0;
   Status  : Status_Kind := Ok;

   Seg_N : Natural := 0;
   Segs : array (0 .. Max_Segments * 5 - 1) of Integer := (others => 0);

   Dot_N : Natural := 0;
   Dots : array (0 .. Max_Dots * 4 - 1) of Integer := (others => 0);
   Work_DX, Work_DY : array (0 .. Max_Dots - 1) of Float := (others => 0.0);
   Work_DC : array (0 .. Max_Dots - 1) of Integer := (others => 0);

   Work_X1, Work_Y1, Work_X2, Work_Y2 :
     array (0 .. Max_Segments - 1) of Float := (others => 0.0);
   Work_Level : array (0 .. Max_Segments - 1) of Integer := (others => 0);
   Work_N : Natural := 0;

   Meta : array (1 .. 12) of Integer := (others => 0);

   Wobble : constant array (0 .. 6) of Float :=
     (0.0, 1.6, -0.9, 1.2, -0.4, 0.8, -1.1);

   function Frame_Depth return Depth_Range is (Frame);
   function Tree_Depth return Tree_Range is (Branches);
   function Segment_Count return Natural is (Seg_N);
   function Segment_X1 (Index : Natural) return Integer is (Segs (Index * 5));
   function Segment_Y1 (Index : Natural) return Integer is (Segs (Index * 5 + 1));
   function Segment_X2 (Index : Natural) return Integer is (Segs (Index * 5 + 2));
   function Segment_Y2 (Index : Natural) return Integer is (Segs (Index * 5 + 3));
   function Segment_Level (Index : Natural) return Integer is (Segs (Index * 5 + 4));
   function Rabbit_Terms return Natural is (Terms);
   function Rabbit_Value return Natural is (Value);
   function Rabbit_Older return Natural is (Older);
   function Rabbit_Newer return Natural is (Newer);
   function Dot_Count return Natural is (Dot_N);
   function Dot_X (Index : Natural) return Integer is (Dots (Index * 4));
   function Dot_Y (Index : Natural) return Integer is (Dots (Index * 4 + 1));
   function Dot_R (Index : Natural) return Integer is (Dots (Index * 4 + 2));
   function Dot_Color (Index : Natural) return Integer is (Dots (Index * 4 + 3));
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
      Meta (2) := Max_Depth;
      Meta (3) := Branches;
      Meta (4) := Seg_N;
      Meta (5) := Terms;
      Meta (6) := Value;
      Meta (7) := Older;
      Meta (8) := Newer;
      Meta (9) := Dot_N;
      Meta (10) := Code (Status);
      Meta (11) := Max_Tree;
      Meta (12) := Max_Terms;
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
      Level : Natural;
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
      if Level = Branches then
         return;
      end if;
      Spread := (30.0 + Wobble (Level mod 7)) * Factor * Pi / 180.0;
      Next := Length * 0.70;
      Branch (X2, Y2, Angle + Spread, Next, Level + 1, Factor * 0.94);
      Branch (X2, Y2, Angle - Spread, Next, Level + 1, Factor * 0.94);
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
      Span := Float'Max (Max_X - Min_X, Max_Y - Min_Y);
      Scale := 920.0 / Span;
      Offset_X := 500.0 - (Min_X + Max_X) * 0.5 * Scale;
      Offset_Y := 500.0 - (Min_Y + Max_Y) * 0.5 * Scale;
      Seg_N := Work_N;
      for I in 0 .. Work_N - 1 loop
         Segs (I * 5) := Integer (Work_X1 (I) * Scale + Offset_X);
         Segs (I * 5 + 1) := Integer (Work_Y1 (I) * Scale + Offset_Y);
         Segs (I * 5 + 2) := Integer (Work_X2 (I) * Scale + Offset_X);
         Segs (I * 5 + 3) := Integer (Work_Y2 (I) * Scale + Offset_Y);
         Segs (I * 5 + 4) := Work_Level (I);
      end loop;
   end Fit_Tree;

   procedure Grow_Tree is
   begin
      Work_N := 0;
      Branch (0.0, 0.0, Pi / 2.0, 1.15, 0, 1.0);
      Fit_Tree;
   end Grow_Tree;

   function Fib (N : Natural) return Natural is
      A : Natural := 1;
      B : Natural := 1;
      C : Natural;
   begin
      if N <= 2 then
         return 1;
      end if;
      for K in 3 .. N loop
         C := A + B;
         A := B;
         B := C;
      end loop;
      return B;
   end Fib;

   function Columns (Count : Natural) return Natural is
      Guess : Natural := 1;
   begin
      while Guess * Guess < Count loop
         Guess := Guess + 1;
      end loop;
      return Guess;
   end Columns;

   procedure Add_Dot (X, Y : Float; Color : Integer) is
   begin
      Work_DX (Dot_N) := X;
      Work_DY (Dot_N) := Y;
      Work_DC (Dot_N) := Color;
      Dot_N := Dot_N + 1;
   end Add_Dot;

   procedure Pack
     (Count : Natural;
      Origin_X, Origin_Y : Float;
      Color : Integer)
   is
      Cols, Rows, Used, Shift : Natural;
      X, Y : Float;
   begin
      if Count = 0 then
         return;
      end if;
      Cols := Columns (Count);
      Rows := (Count + Cols - 1) / Cols;
      for I in 0 .. Count - 1 loop
         if I / Cols = Rows - 1 then
            Used := Count - (Rows - 1) * Cols;
            Shift := Cols - Used;
         else
            Shift := 0;
         end if;
         X := Origin_X + Float (I mod Cols) + Float (Shift) * 0.5;
         Y := Origin_Y + Float (I / Cols);
         Add_Dot (X, Y, Color);
      end loop;
   end Pack;

   procedure Fit_Dots is
      Min_X, Max_X, Min_Y, Max_Y, Span, Scale : Float;
      Radius : Integer;
   begin
      if Dot_N = 0 then
         return;
      end if;
      Min_X := Work_DX (0);
      Max_X := Min_X;
      Min_Y := Work_DY (0);
      Max_Y := Min_Y;
      for I in 0 .. Dot_N - 1 loop
         Min_X := Float'Min (Min_X, Work_DX (I));
         Max_X := Float'Max (Max_X, Work_DX (I));
         Min_Y := Float'Min (Min_Y, Work_DY (I));
         Max_Y := Float'Max (Max_Y, Work_DY (I));
      end loop;
      if Max_X - Min_X < 1.0 then
         Min_X := Min_X - 1.2;
         Max_X := Max_X + 1.2;
      end if;
      if Max_Y - Min_Y < 1.0 then
         Min_Y := Min_Y - 1.2;
         Max_Y := Max_Y + 1.2;
      end if;
      Span := Float'Max (Max_X - Min_X, Max_Y - Min_Y);
      Scale := 760.0 / Span;
      Radius := Integer (0.42 * Scale);
      for I in 0 .. Dot_N - 1 loop
         Dots (I * 4) := Integer ((Work_DX (I) - (Min_X + Max_X) * 0.5) * Scale + 500.0);
         Dots (I * 4 + 1) := Integer ((Work_DY (I) - (Min_Y + Max_Y) * 0.5) * Scale + 500.0);
         Dots (I * 4 + 2) := Radius;
         Dots (I * 4 + 3) := Work_DC (I);
      end loop;
   end Fit_Dots;

   procedure Place_Rabbits is
      Left_Cols : Natural;
   begin
      Dot_N := 0;
      if Terms = 0 then
         return;
      elsif Terms = 1 then
         Add_Dot (0.0, 0.0, 0);
      elsif Terms = 2 then
         Add_Dot (-1.6, 0.0, 0);
         Add_Dot (1.6, 0.0, 1);
      else
         Left_Cols := Columns (Older);
         Pack (Older, 0.0, 0.0, 0);
         Pack (Newer, Float (Left_Cols) + 0.85, 0.0, 1);
      end if;
      Fit_Dots;
   end Place_Rabbits;

   procedure Reset_Rabbits is
   begin
      Terms := 0;
      Value := 0;
      Older := 0;
      Newer := 0;
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
      if Frame = Max_Depth then
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
      if Depth < 0 then
         Branches := 0;
      elsif Depth > Max_Tree then
         Branches := Max_Tree;
      else
         Branches := Depth;
      end if;
      Status := Ok;
      Grow_Tree;
      Publish;
   end Set_Tree;

   procedure Next_Rabbit is
   begin
      if Terms = Max_Terms then
         Status := Full;
         Publish;
         return;
      end if;
      Terms := Terms + 1;
      Value := Fib (Terms);
      if Terms >= 3 then
         Older := Fib (Terms - 2);
         Newer := Fib (Terms - 1);
      else
         Older := 0;
         Newer := 0;
      end if;
      Status := Ok;
      Place_Rabbits;
      Publish;
   end Next_Rabbit;

   function Meta_Address return System.Address is (Meta'Address);
   function Segment_Address return System.Address is (Segs'Address);
   function Dot_Address return System.Address is (Dots'Address);

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
