--  One flying bird on a parallelogram.
--  The body edge is U and the rear edge is V. Rear(t) shifts the rear
--  edge along its outward normal: positive is the tail, negative is the
--  head on the opposite edge. Back(t) shifts the belly edge: positive
--  lifts the wing on the opposite edge. The opposite edge is that curve
--  translated by U or by V. Samples run from 0 to 1. The eye is inside
--  the head.

package Bird_Tile is

   Ux : constant Float := 280.0;
   Uy : constant Float := 22.0;
   Vx : constant Float := 36.0;
   Vy : constant Float := 150.0;

   Sample_Last : constant := 64;

   type Sample_Array is array (0 .. Sample_Last) of Float;

   Rear : constant Sample_Array :=
     (
          0.000,     0.000,     5.268,    18.233,
         23.643,    26.598,    27.888,    27.748,
         26.153,    22.802,    31.535,    26.143,
         31.885,    34.938,    35.994,    35.233,
         32.526,    27.303,    31.564,    20.480,
         23.910,    25.623,    25.963,    24.984,
         22.517,    17.956,     8.396,     0.000,
          0.000,    -0.468,    -8.862,   -11.638,
         -6.435,    -7.887,   -14.788,   -22.695,
        -30.955,   -38.999,   -46.340,   -52.579,
        -57.400,   -60.572,   -61.946,   -61.461,
        -59.139,   -55.087,   -49.494,   -42.637,
        -34.875,   -26.653,   -18.500,   -11.029,
         -4.938,    -1.009,     0.000,     0.000,
          0.000,     0.000,     0.000,     0.000,
          0.000,     0.000,     0.000,     0.000,
          0.000
     );

   Back : constant Sample_Array :=
     (
          0.000,     0.000,     0.000,     0.000,
         18.520,    26.713,    31.932,    35.512,
         37.921,    39.375,    39.977,    39.766,
         38.730,    36.798,    33.817,    29.471,
         46.178,    46.992,    43.764,    49.327,
         53.263,    55.916,    57.466,    57.999,
         57.545,    56.079,    53.519,    49.695,
         57.347,    58.662,    51.946,    31.058,
         33.535,    35.105,    35.886,    35.930,
         35.239,    33.769,    31.410,    27.937,
         22.851,    14.543,     0.000,    -1.062,
         -5.134,   -11.312,   -18.692,   -26.480,
        -33.999,   -40.682,   -46.079,   -49.850,
        -51.772,   -51.732,   -49.734,   -45.892,
        -40.437,   -33.711,   -26.170,   -18.384,
        -11.036,    -4.924,    -0.957,     0.000,
          0.000
     );

   Eye_X : constant Float := 329.04;
   Eye_Y : constant Float := 114.93;
   Eye_R : constant Float := 8.0;
   Pupil_R : constant Float := 3.5;

end Bird_Tile;
