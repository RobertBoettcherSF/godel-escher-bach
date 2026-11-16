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
   Dots : array (0 .. Max_Dots * 5 - 1) of Integer := (others => 0);

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
      Spread := (22.0 + Wobble (Level mod 7)) * Factor * Pi / 180.0;
      Next := (if Level = 0 then 0.85 else Length * 0.66);
      Branch (X2, Y2, Angle + Spread, Next, Level + 1, Factor * 0.97);
      Branch (X2, Y2, Angle - Spread, Next, Level + 1, Factor * 0.97);
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
      Branch (0.0, 0.0, Pi / 2.0, 0.38, 0, 1.0);
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
         Add_Dot (500.0, 540.0, 150, 0, 2);
      elsif Terms = 2 then
         Add_Dot (500.0, 540.0, 150, 1, 2);
      else
         Square_Cols (Older, Cols_A, Rows_A);
         Square_Cols (Newer, Cols_B, Rows_B);
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
         Baseline := (1000.0 - Block - 64.0) / 2.0;
         X := (1000.0
               - (Width_SA + Plus_W + Width_SB + Arrow_W + Width_BA + Split + Width_BB))
              / 2.0;
         Pack_Grid (Older, 0, 0, X, Baseline, Small, Cols_A, Rows_A);
         X := X + Width_SA + Plus_W;
         Pack_Grid (Newer, 1, 1, X, Baseline, Small, Cols_B, Rows_B);
         X := X + Width_SB + Arrow_W;
         Pack_Grid (Older, 0, 2, X, Baseline, Cell, Cols_A, Rows_A);
         X := X + Width_BA + Split;
         Pack_Grid (Newer, 1, 2, X, Baseline, Cell, Cols_B, Rows_B);
      end if;
   end Place_Rabbits;

   procedure Reset_Rabbits is
   begin
      Terms := 1;
      Value := 1;
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
