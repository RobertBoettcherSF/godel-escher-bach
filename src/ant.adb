package body Ant is

   type Word is mod 2**32;

   Nest_X : constant Integer := Width / 2;
   Nest_Y : constant Integer := Height / 2;

   Motif : constant array (0 .. Motif_N - 1) of Integer := (0, 2, 4, 5);

   AX, AY   : array (0 .. Ant_Count - 1) of Integer := (others => Nest_X * Scale);
   AH       : array (0 .. Ant_Count - 1) of Integer := (others => 0);
   Outline  : array (0 .. Outline_N - 1) of Integer := (others => 2);
   Carry    : array (0 .. Ant_Count - 1) of Integer := (others => 0);
   Trail    : array (0 .. Cells - 1) of Integer := (others => 0);
   Food     : array (0 .. Cells - 1) of Integer := (others => 0);
   Groups   : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Sum_X    : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Sum_Y    : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Voices   : array (0 .. Voice_N * 3 - 1) of Integer := (others => 0);
   Meta     : array (0 .. 18) of Integer := (others => 0);
   Rand     : Word := 16#A5F0_1234#;
   Fugue    : Integer := -1;
   Stepped  : Integer := 0;

   function Cell (X : Integer; Y : Integer) return Natural is
     (Natural (Y) * Width + Natural (X));

   function Next_Below (Limit : Positive) return Natural is
   begin
      Rand := Rand * 1_664_525 + 1_013_904_223;
      return Natural (Rand mod Word (Limit));
   end Next_Below;

   function Ant_X (Index : Natural) return Natural is
      Cell_X : Integer;
   begin
      if Index >= Ant_Count or else AX (Index) < 0 then
         return 0;
      end if;
      Cell_X := AX (Index) / Scale;
      if Cell_X >= Width then
         Cell_X := Width - 1;
      end if;
      return Natural (Cell_X);
   end Ant_X;

   function Ant_Y (Index : Natural) return Natural is
      Cell_Y : Integer;
   begin
      if Index >= Ant_Count or else AY (Index) < 0 then
         return 0;
      end if;
      Cell_Y := AY (Index) / Scale;
      if Cell_Y >= Height then
         Cell_Y := Height - 1;
      end if;
      return Natural (Cell_Y);
   end Ant_Y;

   function Carrying (Index : Natural) return Boolean is
     (Index < Ant_Count and then Carry (Index) = 1);

   function In_Bounds return Boolean is
   begin
      for I in 0 .. Ant_Count - 1 loop
         if AX (I) < 0 or else AX (I) >= Width * Scale
           or else AY (I) < 0 or else AY (I) >= Height * Scale
         then
            return False;
         end if;
      end loop;
      return True;
   end In_Bounds;

   function Trail_At (X : Natural; Y : Natural) return Natural is
   begin
      if X >= Width or else Y >= Height then
         return 0;
      end if;
      if Trail (Cell (Integer (X), Integer (Y))) < 0 then
         return 0;
      end if;
      return Natural (Trail (Cell (Integer (X), Integer (Y))));
   end Trail_At;

   function Food_At (X : Natural; Y : Natural) return Natural is
   begin
      if X >= Width or else Y >= Height then
         return 0;
      end if;
      if Food (Cell (Integer (X), Integer (Y))) < 0 then
         return 0;
      end if;
      return Natural (Food (Cell (Integer (X), Integer (Y))));
   end Food_At;

   function Cluster_Of (Index : Natural) return Natural is
      CX : Natural;
      CY : Natural;
   begin
      if Index >= Ant_Count then
         return 0;
      end if;
      CX := Ant_X (Index) / Coarse;
      CY := Ant_Y (Index) / Coarse;
      if CX >= Cluster_W then
         CX := Cluster_W - 1;
      end if;
      if CY >= Cluster_H then
         CY := Cluster_H - 1;
      end if;
      return CY * Cluster_W + CX;
   end Cluster_Of;

   function Cluster_Size (Id : Natural) return Natural is
   begin
      if Id >= Cluster_N or else Groups (Id) < 0 then
         return 0;
      end if;
      return Natural (Groups (Id));
   end Cluster_Size;

   function Step_Milliseconds return Natural is (Step_Ms);

   function Play_Column (Voice : Natural; Beat : Natural) return Integer is
      Slot     : constant Natural := Beat mod Loop_N;
      Start_At : constant Natural := Voice * Motif_N;
   begin
      if Voice >= Voice_N or else Slot < Start_At then
         return -1;
      end if;
      return Integer ((Slot - Start_At) mod Motif_N);
   end Play_Column;

   function Voice_Pitch (Voice : Natural; Beat : Natural) return Integer is
      Note : constant Integer := Play_Column (Voice, Beat);
   begin
      if Note < 0 then
         return -1;
      end if;
      return Motif (Natural (Note));
   end Voice_Pitch;

   procedure Publish is
      Food_Sum : Integer := 0;
      Mass     : Integer := 0;
      SX       : Integer := 0;
      SY       : Integer := 0;
      SXX      : Integer := 0;
      SYY      : Integer := 0;
      Mean_X   : Integer := Nest_X;
      Mean_Y   : Integer := Nest_Y;
      Var_X    : Integer := 4;
      Var_Y    : Integer := 4;
      Phase    : Natural;
   begin
      Groups := (others => 0);
      Sum_X := (others => 0);
      Sum_Y := (others => 0);
      for I in 0 .. Ant_Count - 1 loop
         declare
            Id : constant Natural := Cluster_Of (I);
         begin
            Groups (Id) := Groups (Id) + 1;
            Sum_X (Id) := Sum_X (Id) + AX (I);
            Sum_Y (Id) := Sum_Y (Id) + AY (I);
         end;
      end loop;

      for I in Trail'Range loop
         Food_Sum := Food_Sum + Food (I);
         if Trail (I) > 0 then
            declare
               X : constant Integer := Integer (I mod Width);
               Y : constant Integer := Integer (I / Width);
               W : constant Integer := Trail (I);
            begin
               Mass := Mass + W;
               SX := SX + X * W;
               SY := SY + Y * W;
               SXX := SXX + X * X * W;
               SYY := SYY + Y * Y * W;
            end;
         end if;
      end loop;

      if Mass > 0 then
         Mean_X := SX / Mass;
         Mean_Y := SY / Mass;
         Var_X := SXX / Mass - Mean_X * Mean_X;
         Var_Y := SYY / Mass - Mean_Y * Mean_Y;
         if Var_X < 1 then
            Var_X := 1;
         end if;
         if Var_Y < 1 then
            Var_Y := 1;
         end if;
      end if;

      for V in 0 .. Voice_N - 1 loop
         Voices (V * 3) := 0;
         Voices (V * 3 + 1) := -1;
         Voices (V * 3 + 2) := -1;
      end loop;
      if Fugue >= 0 then
         Phase := Natural (Fugue);
         for V in 0 .. Voice_N - 1 loop
            declare
               Note : constant Integer := Play_Column (V, Phase);
            begin
               if Note >= 0 then
                  Voices (V * 3) := 1;
                  Voices (V * 3 + 1) := Note;
                  Voices (V * 3 + 2) := Motif (Natural (Note));
               end if;
            end;
         end loop;
      end if;

      Outline := (others => 0);
      if Mass > 0 then
         for I in Trail'Range loop
            if Trail (I) > 1 then
               declare
                  X    : constant Integer := Integer (I mod Width);
                  Y    : constant Integer := Integer (I / Width);
                  DX   : constant Integer := X - Mean_X;
                  DY   : constant Integer := Y - Mean_Y;
                  Best : Integer := -1_000_000;
                  Slot : Natural := 0;
                  Dist : Integer;
                  Cos16 : constant array (0 .. 15) of Integer :=
                    (64, 59, 45, 24, 0, -24, -45, -59,
                     -64, -59, -45, -24, 0, 24, 45, 59);
                  Sin16 : constant array (0 .. 15) of Integer :=
                    (0, 24, 45, 59, 64, 59, 45, 24,
                     0, -24, -45, -59, -64, -59, -45, -24);
               begin
                  for H in Cos16'Range loop
                     declare
                        Dot : constant Integer := DX * Cos16 (H) + DY * Sin16 (H);
                     begin
                        if Dot > Best then
                           Best := Dot;
                           Slot := H;
                        end if;
                     end;
                  end loop;
                  Dist := abs (DX);
                  if abs (DY) > Dist then
                     Dist := abs (DY);
                  end if;
                  if Dist > Outline (Slot) then
                     Outline (Slot) := Dist;
                  end if;
               end;
            end if;
         end loop;
         declare
            Filled : array (0 .. Outline_N - 1) of Integer := (others => 0);
         begin
            for H in Outline'Range loop
               if Outline (H) > 0 then
                  Filled (H) := Outline (H);
               else
                  declare
                     Left_D  : Natural := 1;
                     Right_D : Natural := 1;
                     Left_V  : Integer := 0;
                     Right_V : Integer := 0;
                  begin
                     while Left_D < Outline_N
                       and then Outline ((H + Outline_N - Left_D) mod Outline_N) = 0
                     loop
                        Left_D := Left_D + 1;
                     end loop;
                     while Right_D < Outline_N
                       and then Outline ((H + Right_D) mod Outline_N) = 0
                     loop
                        Right_D := Right_D + 1;
                     end loop;
                     if Left_D < Outline_N and then Right_D < Outline_N then
                        Left_V := Outline ((H + Outline_N - Left_D) mod Outline_N);
                        Right_V := Outline ((H + Right_D) mod Outline_N);
                        Filled (H) :=
                          (Left_V * Integer (Right_D) + Right_V * Integer (Left_D))
                          / Integer (Left_D + Right_D);
                     end if;
                  end;
               end if;
            end loop;
            for H in Outline'Range loop
               Outline (H) := Filled (H);
            end loop;
         end;
      else
         Outline := (others => 2);
      end if;

      Meta :=
        (Ant_Count, Width, Height, Trail_Max, Nest_X, Nest_Y, Food_Sum, Stepped,
         Cluster_N, Voice_N, Motif_N, Loop_N, Fugue, Step_Ms, Mean_X, Mean_Y,
         Var_X, Var_Y, Scale);
   end Publish;

   procedure Reset is
   begin
      Rand := 16#A5F0_1234#;
      Trail := (others => 0);
      Food := (others => 0);
      Carry := (others => 0);
      Stepped := 0;
      Fugue := -1;
      for I in 0 .. Ant_Count - 1 loop
         AX (I) := Integer (Next_Below ((Width - 2) * Scale)) + Scale;
         AY (I) := Integer (Next_Below ((Height - 2) * Scale)) + Scale;
         AH (I) := Integer (Next_Below (8));
      end loop;
      Food (Cell (Seed_X1, Seed_Y1)) := 40;
      Food (Cell (Seed_X2, Seed_Y2)) := 40;
      Publish;
   end Reset;

   procedure Reseed (Value : Natural) is
   begin
      Rand := Word (Value) * 1_664_525 + 1;
      if Rand = 0 then
         Rand := 1;
      end if;
   end Reseed;

   procedure Set_Trail (X : Natural; Y : Natural; Value : Natural) is
      Amount : Natural := Value;
   begin
      if X >= Width or else Y >= Height then
         return;
      end if;
      if Amount > Trail_Max then
         Amount := Trail_Max;
      end if;
      Trail (Cell (Integer (X), Integer (Y))) := Integer (Amount);
   end Set_Trail;

   procedure Clear_Loads is
   begin
      Carry := (others => 0);
      Food := (others => 0);
      Publish;
   end Clear_Loads;

   procedure Drop_Food (X : Natural; Y : Natural) is
      Id : Natural;
   begin
      if X >= Width or else Y >= Height then
         return;
      end if;
      if Integer (X) = Nest_X and then Integer (Y) = Nest_Y then
         return;
      end if;
      Id := Cell (Integer (X), Integer (Y));
      Food (Id) := Food (Id) + Food_Add;
      if Food (Id) > Food_Max then
         Food (Id) := Food_Max;
      end if;
      Publish;
   end Drop_Food;

   function Heading_Of (DX : Integer; DY : Integer) return Natural is
      Best : Integer := -1_000_000;
      Pick : Natural := 0;
      VX   : Integer;
      VY   : Integer;
      Dot  : Integer;
   begin
      for H in 0 .. 7 loop
         case H is
            when 0 => VX := 4; VY := 0;
            when 1 => VX := 3; VY := 3;
            when 2 => VX := 0; VY := 4;
            when 3 => VX := -3; VY := 3;
            when 4 => VX := -4; VY := 0;
            when 5 => VX := -3; VY := -3;
            when 6 => VX := 0; VY := -4;
            when 7 => VX := 3; VY := -3;
         end case;
         Dot := DX * VX + DY * VY;
         if Dot > Best then
            Best := Dot;
            Pick := H;
         end if;
      end loop;
      return Pick;
   end Heading_Of;

   function Turn_Toward (From : Natural; To : Natural) return Natural is
      Diff : Integer := Integer (To) - Integer (From);
   begin
      if Diff > 4 then
         Diff := Diff - 8;
      elsif Diff < -4 then
         Diff := Diff + 8;
      end if;
      if Diff > 0 then
         return (From + 1) mod 8;
      elsif Diff < 0 then
         return (From + 7) mod 8;
      end if;
      return From;
   end Turn_Toward;

   procedure Step_Delta (Heading : Natural; MX : out Integer; MY : out Integer) is
   begin
      case Heading is
         when 0 => MX := 28; MY := 0;
         when 1 => MX := 20; MY := 20;
         when 2 => MX := 0; MY := 28;
         when 3 => MX := -20; MY := 20;
         when 4 => MX := -28; MY := 0;
         when 5 => MX := -20; MY := -20;
         when 6 => MX := 0; MY := -28;
         when others => MX := 20; MY := -20;
      end case;
   end Step_Delta;

   function Nearest_Food (X : Integer; Y : Integer) return Natural is
      Best : Integer := Integer'Last;
      Pick : Natural := 0;
      Seen : Boolean := False;
   begin
      for F in Food'Range loop
         if Food (F) > 0 then
            declare
               FX   : constant Integer := Integer (F mod Width) * Scale + Scale / 2;
               FY   : constant Integer := Integer (F / Width) * Scale + Scale / 2;
               Dist : constant Integer := abs (X - FX) + abs (Y - FY);
            begin
               if not Seen or else Dist < Best then
                  Best := Dist;
                  Pick := F;
                  Seen := True;
               end if;
            end;
         end if;
      end loop;
      return Pick;
   end Nearest_Food;

   procedure Step is
      Speed_X : Integer;
      Speed_Y : Integer;
   begin
      for I in 0 .. Ant_Count - 1 loop
         declare
            Cell_X : Integer := AX (I) / Scale;
            Cell_Y : Integer := AY (I) / Scale;
            Want   : Natural;
            Here   : Natural;
         begin
            if Cell_X < 0 then
               Cell_X := 0;
            elsif Cell_X >= Width then
               Cell_X := Width - 1;
            end if;
            if Cell_Y < 0 then
               Cell_Y := 0;
            elsif Cell_Y >= Height then
               Cell_Y := Height - 1;
            end if;
            Here := Cell (Cell_X, Cell_Y);
            if Carry (I) = 1 then
               Want := Heading_Of
                 (Nest_X * Scale + Scale / 2 - AX (I),
                  Nest_Y * Scale + Scale / 2 - AY (I));
               Trail (Here) := Trail (Here) + 10;
               if Trail (Here) > Trail_Max then
                  Trail (Here) := Trail_Max;
               end if;
            elsif I < 36 then
               declare
                  Food_Cell : constant Natural := Nearest_Food (AX (I), AY (I));
               begin
                  if Food (Food_Cell) > 0 then
                     Want := Heading_Of
                       (Integer (Food_Cell mod Width) * Scale + Scale / 2 - AX (I),
                        Integer (Food_Cell / Width) * Scale + Scale / 2 - AY (I));
                  else
                     Want := Natural (AH (I));
                  end if;
               end;
            else
               Want := Natural (AH (I));
            end if;
            if Next_Below (6) = 0 then
               if Next_Below (2) = 0 then
                  Want := (Want + 1) mod 8;
               else
                  Want := (Want + 7) mod 8;
               end if;
            end if;
            AH (I) := Integer (Turn_Toward (Natural (AH (I)), Want));
            Step_Delta (Natural (AH (I)), Speed_X, Speed_Y);
            AX (I) := AX (I) + Speed_X;
            AY (I) := AY (I) + Speed_Y;
            if AX (I) < Scale / 4 then
               AX (I) := Scale / 4;
               AH (I) := Integer ((Natural (AH (I)) + 4) mod 8);
            elsif AX (I) >= Width * Scale - Scale / 4 then
               AX (I) := Width * Scale - Scale / 4 - 1;
               AH (I) := Integer ((Natural (AH (I)) + 4) mod 8);
            end if;
            if AY (I) < Scale / 4 then
               AY (I) := Scale / 4;
               AH (I) := Integer ((Natural (AH (I)) + 4) mod 8);
            elsif AY (I) >= Height * Scale - Scale / 4 then
               AY (I) := Height * Scale - Scale / 4 - 1;
               AH (I) := Integer ((Natural (AH (I)) + 4) mod 8);
            end if;
            Cell_X := AX (I) / Scale;
            Cell_Y := AY (I) / Scale;
            if Cell_X >= Width then
               Cell_X := Width - 1;
            end if;
            if Cell_Y >= Height then
               Cell_Y := Height - 1;
            end if;
            Here := Cell (Cell_X, Cell_Y);
            if Carry (I) = 1 and then Cell_X = Nest_X and then Cell_Y = Nest_Y then
               Carry (I) := 0;
            elsif Carry (I) = 0 and then Food (Here) > 0
              and then not (Cell_X = Nest_X and then Cell_Y = Nest_Y)
            then
               Food (Here) := Food (Here) - 1;
               Carry (I) := 1;
            end if;
         end;
      end loop;

      if Stepped mod 12 = 0 then
         for I in Trail'Range loop
            if Trail (I) > 0 then
               Trail (I) := Trail (I) - 1;
            end if;
         end loop;
      end if;
      Stepped := Stepped + 1;
      Publish;
   end Step;

   procedure Steps (Count : Natural) is
   begin
      for Turn in 1 .. Count loop
         Step;
      end loop;
   end Steps;

   procedure Set_Beat (Beat : Integer) is
   begin
      if Beat < 0 then
         Fugue := -1;
      else
         Fugue := Integer (Natural (Beat) mod Loop_N);
      end if;
      Publish;
   end Set_Beat;

   function Meta_Address return System.Address is (Meta'Address);
   function X_Address return System.Address is (AX'Address);
   function Y_Address return System.Address is (AY'Address);
   function Carry_Address return System.Address is (Carry'Address);
   function Trail_Address return System.Address is (Trail'Address);
   function Food_Address return System.Address is (Food'Address);
   function Cluster_Address return System.Address is (Groups'Address);
   function Sum_X_Address return System.Address is (Sum_X'Address);
   function Sum_Y_Address return System.Address is (Sum_Y'Address);
   function Motif_Address return System.Address is (Motif'Address);
   function Voice_Address return System.Address is (Voices'Address);
   function Head_Address return System.Address is (AH'Address);
   function Outline_Address return System.Address is (Outline'Address);

   procedure Reset_Exported is
   begin
      Reset;
   end Reset_Exported;

   procedure Step_Exported is
   begin
      Step;
   end Step_Exported;

   procedure Drop_Exported (X : Integer; Y : Integer) is
   begin
      if X < 0 or else Y < 0 then
         return;
      end if;
      Drop_Food (Natural (X), Natural (Y));
   end Drop_Exported;

   procedure Set_Beat_Exported (Beat : Integer) is
   begin
      Set_Beat (Beat);
   end Set_Beat_Exported;

end Ant;
