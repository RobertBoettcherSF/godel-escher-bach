package body Ant is

   type Word is mod 2**32;

   Nest_X : constant Integer := Width / 2;
   Nest_Y : constant Integer := Height / 2;

   DX : constant array (0 .. 3) of Integer := (0, 1, 0, -1);
   DY : constant array (0 .. 3) of Integer := (-1, 0, 1, 0);

   Motif : constant array (0 .. Motif_N - 1) of Integer := (0, 2, 4, 5);

   AX, AY   : array (0 .. Ant_Count - 1) of Integer := (others => Nest_X);
   Carry    : array (0 .. Ant_Count - 1) of Integer := (others => 0);
   Trail    : array (0 .. Cells - 1) of Integer := (others => 0);
   Food     : array (0 .. Cells - 1) of Integer := (others => 0);
   Groups   : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Sum_X    : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Sum_Y    : array (0 .. Cluster_N - 1) of Integer := (others => 0);
   Voices   : array (0 .. Voice_N * 3 - 1) of Integer := (others => 0);
   Meta     : array (0 .. 17) of Integer := (others => 0);
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
   begin
      if Index >= Ant_Count or else AX (Index) < 0 then
         return 0;
      end if;
      return Natural (AX (Index));
   end Ant_X;

   function Ant_Y (Index : Natural) return Natural is
   begin
      if Index >= Ant_Count or else AY (Index) < 0 then
         return 0;
      end if;
      return Natural (AY (Index));
   end Ant_Y;

   function Carrying (Index : Natural) return Boolean is
     (Index < Ant_Count and then Carry (Index) = 1);

   function In_Bounds return Boolean is
   begin
      for I in 0 .. Ant_Count - 1 loop
         if AX (I) < 0 or else AX (I) >= Width
           or else AY (I) < 0 or else AY (I) >= Height
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

      Meta :=
        (Ant_Count, Width, Height, Trail_Max, Nest_X, Nest_Y, Food_Sum, Stepped,
         Cluster_N, Voice_N, Motif_N, Loop_N, Fugue, Step_Ms, Mean_X, Mean_Y,
         Var_X, Var_Y);
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
         AX (I) := Nest_X + Integer (Next_Below (7)) - 3;
         AY (I) := Nest_Y + Integer (Next_Below (5)) - 2;
         if AX (I) < 0 then
            AX (I) := 0;
         elsif AX (I) >= Width then
            AX (I) := Width - 1;
         end if;
         if AY (I) < 0 then
            AY (I) := 0;
         elsif AY (I) >= Height then
            AY (I) := Height - 1;
         end if;
      end loop;
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

   procedure Step is
   begin
      for I in 0 .. Ant_Count - 1 loop
         declare
            Best : Integer := -1;
            NX   : Integer := AX (I);
            NY   : Integer := AY (I);
         begin
            for D in 0 .. 3 loop
               declare
                  TX    : constant Integer := AX (I) + DX (D);
                  TY    : constant Integer := AY (I) + DY (D);
                  Score : Integer;
               begin
                  if TX in 0 .. Width - 1 and then TY in 0 .. Height - 1 then
                     Score := Trail (Cell (TX, TY)) * 4 + Integer (Next_Below (4));
                     if Carry (I) = 1 then
                        Score := Score + (Width - abs (TX - Nest_X)) * 2
                          + (Height - abs (TY - Nest_Y)) * 2;
                     else
                        Score := Score + Food (Cell (TX, TY)) * 6;
                        declare
                           Pull : Integer := 0;
                        begin
                           for F in Food'Range loop
                              if Food (F) > 0 then
                                 declare
                                    FX : constant Integer := Integer (F mod Width);
                                    FY : constant Integer := Integer (F / Width);
                                    Here : constant Integer :=
                                      Width + Height - abs (TX - FX) - abs (TY - FY);
                                 begin
                                    if Here > Pull then
                                       Pull := Here;
                                    end if;
                                 end;
                              end if;
                           end loop;
                           Score := Score + Pull;
                        end;
                     end if;
                     if Score > Best then
                        Best := Score;
                        NX := TX;
                        NY := TY;
                     end if;
                  end if;
               end;
            end loop;

            if Carry (I) = 1 then
               declare
                  Id : constant Natural := Cell (AX (I), AY (I));
               begin
                  Trail (Id) := Trail (Id) + 8;
                  if Trail (Id) > Trail_Max then
                     Trail (Id) := Trail_Max;
                  end if;
               end;
            end if;

            if Best >= 0 then
               AX (I) := NX;
               AY (I) := NY;
            end if;

            declare
               Id : constant Natural := Cell (AX (I), AY (I));
            begin
               if Carry (I) = 1 and then AX (I) = Nest_X and then AY (I) = Nest_Y then
                  Carry (I) := 0;
               elsif Carry (I) = 0 and then Food (Id) > 0
                 and then not (AX (I) = Nest_X and then AY (I) = Nest_Y)
               then
                  Food (Id) := Food (Id) - 1;
                  Carry (I) := 1;
               end if;
            end;
         end;
      end loop;

      for I in Trail'Range loop
         if Trail (I) > 0 then
            Trail (I) := Trail (I) - 1;
         end if;
      end loop;
      Stepped := Stepped + 1;
      Publish;
   end Step;

   procedure Steps (Count : Natural) is
      N : Natural := Count;
   begin
      if N > 3 then
         N := 3;
      end if;
      for Turn in 1 .. N loop
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
