with Ada.Command_Line;
with Ada.Text_IO;
with Ant;

procedure Ant_Smoke is
   use Ada.Text_IO;

   type Word is mod 2**32;

   Failures : Natural := 0;
   Seed     : Word := 1;

   procedure Check (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         Failures := Failures + 1;
         Put_Line ("FAIL " & Message);
      end if;
   end Check;

   function Next_Rand return Natural is
   begin
      Seed := Seed * 1664525 + 1013904223;
      return Natural (Seed mod 2_147_483_647);
   end Next_Rand;

   procedure Check_World (Tag : String) is
      Sum : Natural := 0;
   begin
      Check (Ant.In_Bounds, Tag & " bounds");
      for I in 0 .. Ant.Ant_Count - 1 loop
         Check (Ant.Ant_X (I) < Ant.Width, Tag & " x");
         Check (Ant.Ant_Y (I) < Ant.Height, Tag & " y");
         Sum := Sum + 1;
      end loop;
      Check (Sum = Ant.Ant_Count, Tag & " count");
      for Y in 0 .. Ant.Height - 1 loop
         for X in 0 .. Ant.Width - 1 loop
            Check (Ant.Trail_At (X, Y) <= Ant.Trail_Max, Tag & " trail cap");
         end loop;
      end loop;
      declare
         Tallies : array (0 .. Ant.Cluster_N - 1) of Natural := (others => 0);
         Total   : Natural := 0;
      begin
         for I in 0 .. Ant.Ant_Count - 1 loop
            Tallies (Ant.Cluster_Of (I)) := Tallies (Ant.Cluster_Of (I)) + 1;
         end loop;
         for Id in Tallies'Range loop
            Check (Tallies (Id) = Ant.Cluster_Size (Id), Tag & " cluster");
            Total := Total + Ant.Cluster_Size (Id);
         end loop;
         Check (Total = Ant.Ant_Count, Tag & " partition");
      end;
   end Check_World;
begin
   Ant.Reset;
   Check (Ant.In_Bounds, "reset bounds");
   Check_World ("reset");
   Check (Ant.Play_Column (0, 0) = 0, "first voice starts");
   Check (Ant.Play_Column (1, 0) = -1, "second voice waits");
   Check (Ant.Play_Column (3, 12) = 0, "last voice enters");
   Check (Ant.Voice_Pitch (0, 1) = 2, "second note of the tune");
   Check (Ant.Voice_Pitch (2, 3) = -1, "quiet before entry");
   Check (Ant.Step_Milliseconds = 420, "fugue step");

   for Trial in 1 .. 12 loop
      Ant.Reset;
      Ant.Reseed (1_000 + Next_Rand mod 50_000);
      Ant.Drop_Food (Next_Rand mod Ant.Width, Next_Rand mod Ant.Height);
      Ant.Drop_Food (Next_Rand mod Ant.Width, Next_Rand mod Ant.Height);
      Ant.Steps (8);
      Check_World ("seeded");
   end loop;

   Ant.Reset;
   Ant.Clear_Loads;
   for Y in 0 .. Ant.Height - 1 loop
      for X in 0 .. Ant.Width - 1 loop
         Ant.Set_Trail (X, Y, (X + 2 * Y) mod (Ant.Trail_Max + 1));
      end loop;
   end loop;
   for Turn in 1 .. Ant.Trail_Max + 2 loop
      declare
         Before : array (0 .. Ant.Width - 1, 0 .. Ant.Height - 1) of Natural;
      begin
         for Y in 0 .. Ant.Height - 1 loop
            for X in 0 .. Ant.Width - 1 loop
               Before (X, Y) := Ant.Trail_At (X, Y);
            end loop;
         end loop;
         Ant.Step;
         for Y in 0 .. Ant.Height - 1 loop
            for X in 0 .. Ant.Width - 1 loop
               Check (Ant.Trail_At (X, Y) <= Before (X, Y), "trail fades");
               Check (Ant.Trail_At (X, Y) <= Ant.Trail_Max, "trail bound");
            end loop;
         end loop;
      end;
   end loop;
   Check_World ("after fade");

   if Failures = 0 then
      Put_Line ("ant smoke ok");
   else
      Put_Line ("ant smoke failed:" & Failures'Image);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Ant_Smoke;
