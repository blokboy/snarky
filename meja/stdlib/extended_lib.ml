let line = __LINE__ + 3

let t =
  {meja|
module Extended_lib = {
  type quadruple('a) = ('a, 'a, 'a, 'a);
  type triple('a) = ('a, 'a, 'a);
  type double('a) = ('a, 'a);

  let max_int32 = 4294967295i;

  module UInt32 = {
    let length = 32i;

    type t = array(boolean);

    let xor : t -> t -> t = fun (t1, t2) => {
      Array.map2(Boolean.lxor, t1, t2);
    };

    let zero : t = Array.init(length, fun (_) => { 0b; });

    let ceil_log2 = loop(fun (self, n) => {
      switch (n) {
        | 0i => 0i
        | _ => 1i + self(n / 2i)
      };
    });

    let take = fun (n, xs) => {
      let (xs, _) =
        List.fold_left(fun ((xs, k), x) => {
          switch (k >= n) {
            | true => (xs, k)
            | false => (x :: xs, k + 1i)
          };
        }, ([], 0i), xs);
      List.rev(xs);
    };

    let sum : list(t) -> t = fun (xs) => {
      let max_bit_length : int = ceil_log2(List.length(xs) * max_int32);
      let xs_sum =
        List.fold_left(
          fun (acc, x) => {
            Field.(+)(Field.of_bits(Array.to_list(x)), acc);
          }, 
          0,
          xs);
      take(
        32i,
        // TODO: Habe allow_overflow:false
        Field.to_bits(~length=max_bit_length, xs_sum))
      |> Array.of_list;
    };

    let rotr : t -> int -> t = fun (t, by) => {
      Array.init(length, fun (i) => {
          Array.get(t, (mod(i + by, length))); });
    };

    let int_get_bit = fun (n : int, i : int) => {
      switch(land(lsr(n, i), 1i)) {
        | 1i => 1b
        | _ => 0b
      };
    };

    let of_int : int -> t = fun (n) => {
      loop( 
        fun (self, (i, acc)) => {
          switch (i) {
            | 32i => acc
            | _ =>
              self((i + 1i,  int_get_bit(n, (31i - i)) :: acc))
          };
        },
        (0i, [])
      ) |> Array.of_list;
    };
  };

  module Blake2 = {
    let r1 = 16i;

    let r2 = 12i;

    let r3 = 8i;

    let r4 = 7i;

    let mixing_g = fun (v, a, b, c, d, x, y) => {
      let ( = ) = fun (i, t) => { Array.set(v, i, t); };
      let (!) = Array.get(v);
      let sum = UInt32.sum;
      let xorrot = fun (t1, t2, k) => {
        UInt32.rotr(UInt32.xor(t1, t2), k);
      };
      a = sum([!a, !b, x]) ;
      d = xorrot( !d, !a, r1 );
      c = sum([!c, !d]);
      b = xorrot( !b, !c, r2 );
      a = sum([ !a, !b, y]);
      d = xorrot(!d, !a, r3);
      c = sum([!c, !d]);
      b = xorrot(!b, !c, r4);
    };

    let iv =
      Array.map(
        UInt32.of_int,
        Array.of_list(
          [ 1779033703i
          , 3144134277i
          , 1013904242i
          , 2773480762i
          , 1359893119i
          , 2600822924i
          , 528734635i
          , 1541459225i ]));

    let sigma =
      Array.of_list (
      [ [0i, 1i, 2i, 3i, 4i, 5i, 6i, 7i, 8i, 9i, 10i, 11i, 12i, 13i, 14i, 15i]
      , [14i, 10i, 4i, 8i, 9i, 15i, 13i, 6i, 1i, 12i, 0i, 2i, 11i, 7i, 5i, 3i]
      , [11i, 8i, 12i, 0i, 5i, 2i, 15i, 13i, 10i, 14i, 3i, 6i, 7i, 1i, 9i, 4i]
      , [7i, 9i, 3i, 1i, 13i, 12i, 11i, 14i, 2i, 6i, 5i, 10i, 4i, 0i, 15i, 8i]
      , [9i, 0i, 5i, 7i, 2i, 4i, 10i, 15i, 14i, 1i, 11i, 12i, 6i, 8i, 3i, 13i]
      , [2i, 12i, 6i, 10i, 0i, 11i, 8i, 3i, 4i, 13i, 7i, 5i, 15i, 14i, 1i, 9i]
      , [12i, 5i, 1i, 15i, 14i, 13i, 4i, 10i, 0i, 7i, 6i, 3i, 9i, 2i, 8i, 11i]
      , [13i, 11i, 7i, 14i, 12i, 1i, 3i, 9i, 5i, 0i, 15i, 4i, 8i, 6i, 2i, 10i]
      , [6i, 15i, 14i, 9i, 11i, 3i, 0i, 8i, 12i, 2i, 13i, 7i, 1i, 4i, 10i, 5i]
      , [10i, 2i, 8i, 4i, 7i, 6i, 1i, 5i, 15i, 11i, 9i, 14i, 3i, 12i, 13i, 0i] ] )
      |> Array.map(Array.of_list);

    let splitu64 = fun (u : Int64.t) => {
      let low = Int64.logand(u, Int64.of_int(max_int32));
      let high = Int64.shift_right(u, 32i);
      (low, high);
    };

    let for_ : int -> (int -> unit) -> unit = fun (n, f) => {
      loop(fun(self, i) => {
        switch (i = n) {
          | true => ()
          | false => {
            f(i);
            self(i + 1i);
            }
        };
      }, 0i);
    };

    open UInt32;

    let compression = fun (h, m : array(UInt32.t), t, f) => {
      let v = Array.append (h, iv);
      let (tlo, thi) = splitu64(t);
      Array.set(v, 12i, xor(Array.get(v, 12i), of_int(Int64.to_int(tlo))));
      Array.set(v, 13i, xor(Array.get(v, 13i), of_int(Int64.to_int(thi))));

      switch (f) {
        | false => ()
        | true =>
          Array.set(v, 14i, xor(Array.get(v, 14i), of_int(max_int32)))
      };

      for_(10i, fun (i) => {
        let s = Array.get(sigma, i);
        let mix = fun (a, b, c, d, i1, i2) => {
          mixing_g(v, a, b, c, d, Array.get(m, Array.get(s, i1)), Array.get(m, Array.get(s, i2)));
        };
        mix(0i, 4i, 8i, 12i, 0i, 1i);
        mix(1i, 5i, 9i, 13i, 2i, 3i);
        mix(2i, 6i,10i, 14i, 4i, 5i);
        mix(3i, 7i,11i, 15i, 6i, 7i);
        mix(0i, 5i,10i, 15i, 8i, 9i);
        mix(1i, 6i,11i, 12i,10i,11i);
        mix(2i, 7i, 8i, 13i,12i,13i);
        mix(3i, 4i, 9i, 14i,14i,15i);
      });

      for_(8i, fun(i) => {
        Array.set(h, i, xor(Array.get(h, i), Array.get(v, i)));
        Array.set(h, i, xor(Array.get(h, i), Array.get(v, i + 8i)));
      });
    };

    let block_size_in_bits = 512i;

    let digest_length_in_bits = 256i;

    let pad_input = fun (bs) => {
      let n = Array.length(bs);
      switch (mod(n, block_size_in_bits)) {
        | 0i => bs
        | k => 
          Array.append(bs,
            Array.create(block_size_in_bits - k, 0b))
      };
    };

    let concat_int32s = fun (ts : array(UInt32.t)) => {
      let n = Array.length(ts);
      Array.init(n * UInt32.length, fun (i) => {
        Array.get(
          Array.get(ts, (i / UInt32.length)),
          mod(i, UInt32.length));
      });
    };

    let personalization =
      String.init( 8i, fun (_) => { char_of_int(0i); });

    let blake2s : list(boolean) -> list(boolean) = fun (input) => {
      let input = Array.of_list(input);
      let p = fun (o) => {
        let c = fun(j) => {
          lsl(
            int_of_char(String.get(personalization, o + j)),
            8i * j);
        };
        c(0i) + c(1i) + c(2i) + c(3i);
      };
      let h =
        /* Here we xor the initial values with the parameters of the
          hash function that we're using:
          depth = 1
          fanout = 1
          digest_length = 32
          personalization = personalization */
        Array.map(
          UInt32.of_int,
          Array.of_list(
            [ lxor(1779033703i, 16842752i)
            , 3144134277i
            , 1013904242i
            , 2773480762i
            , 1359893119i
            , 2600822924i
            , lxor(528734635i, p(0i))
            , lxor(1541459225i, p(4i))
            ]));
      let padded = pad_input(input);
      let blocks : array(array(UInt32.t)) = {
        let n = Array.length(padded);
        switch (n) {
          | 0i =>
            Array.of_list(
              [ Array.create(
                  block_size_in_bits / UInt32.length,
                  UInt32.zero) ])
          | _ =>
            Array.init(n / block_size_in_bits, fun (i) => {
                Array.init(block_size_in_bits / UInt32.length, fun (j) => {
                    Array.init(UInt32.length, fun (k) => {
                      Array.get(padded,
                                (block_size_in_bits * i)
                                + (UInt32.length * j)
                                + k);
                    });
                });
            })
        };
      };
      for_(Array.length(blocks) - 1i, fun (i) => {
          compression(
            h, Array.get(blocks ,i),
            Int64.mul(
              Int64.add(Int64.of_int(i), Int64.of_int(1i)),
              Int64.of_int(64i)),
            false);
      });
      let input_length_in_bytes = (Array.length(input) + 7i) / 8i;
      compression(h,
        Array.get(blocks, Array.length(blocks) - 1i),
        Int64.of_int(input_length_in_bytes),
        true);
      concat_int32s(h) |> Array.to_list;
    };

    let string_to_bool_list = fun (s) => {
      List.init(8i * String.length(s), fun (i) => {
        let c = int_of_char(String.get(s, i / 8i));
        let j = mod(i, 8i);
        land(lsr(c,j), 1i) = 1i;
      });
    };
  };

  module Curve = {
    open Field;

    // Would be nice to have "subset syntax" for the Typ for this type.
    type t = double(field);

    request(field) Div(field, field)
    with handler (x, y) => { respond(Provide(x / y)); };

    let div_unsafe = fun (x, y) => {
      let z : field =  request { Div(x, y); };
      assert_r1(x, y, z) ;
      z;
      /* It would be nice if this were a special syntax but that's
          a "nice to have" */
      /* assert (x * y == z); */
    };

    request(field) Addx { lambda : field, ax : field, bx : field }
    with handler ({ lambda, ax, bx } ) => {
      let res = square(lambda) - (ax + bx);
      respond(Provide(res));
    };

    request(field) Addy { lambda : field, ax : field, ay : field, cx : field }
    with handler ({ lambda, ax, ay, cx } ) => {
      let res = (lambda * (ax - cx)) - ay;
      respond(Provide(res));
    };
    
    let add_unsafe = fun ((ax, ay), (bx, by)) => {
      let lambda = div_unsafe(Field.(-)(by, ay), Field.(-)(bx, ax));
      let cx = request { Addx { lambda, ax, bx }; };
      let cy = request { Addy { lambda, ax, ay, cx }; };
      assert_r1(lambda, lambda, cx + ax + bx);
      assert_r1(lambda, (ax - cx) , (cy + ay));
      (cx, cy);
    };
  };

  module Pedersen = {
    module Digest = {
      type t = field;
    };

    module Params = {
      type t = array(quadruple((field, field)));
    };

    /*
  let params = {
      let comma = char_of_int(44i);
      let semi_colon = char_of_int(59i);

      let read_pair = fun (s) => {
        switch (String.split_on_char(comma, s)) {
          | [ x, y ] =>
            (Field.of_string(x), Field.of_string(y))
        };
      };

      let strs = Array.of_list(In_channel.read_lines("bn128-params"));

      Array.map(fun (s) => {
        switch ( List.map(read_pair, String.split_on_char(semi_colon, s)) ) {
          | [x1, x2, x3, x4] => (x1, x2, x3, x4)
        };
      }, strs);
    }; */

    /* 4 * 2 = 2 * 4 */
    let transpose : quadruple(double('a)) -> double(quadruple('a)) =
      fun ( ((x0, y0), (x1, y1), (x2, y2), (x3, y3)) ) => {
        ( (x0, x1, x2, x3), (y0, y1, y2, y3) );
      };

    let add_int = ( + );

    open Field;

    let lookup = fun ((s0, s1, s2) : triple(boolean), q : quadruple(Curve.t)) => {
      let s_and = Boolean.(&&)(s0, s1) ;
      let bool : boolean -> field = Boolean.to_field;
      let lookup_one = fun ((a1, a2, a3, a4)) => {
        a1
        + ((a2 - a1) * bool(s0)) /* Need some way to make booleans field elements */
        + ((a3 - a1) * bool(s1))
        + ((a4 + a1 - a2 - a3) * bool(s_and));
      };
      let (x_q, y_q) = transpose(q);
      (lookup_one(x_q), (1 - 2 * bool(s2)) * lookup_one(y_q)); 
    };

    let digest = fun (params, triples : list(triple(boolean))) : Digest.t => {
      switch (triples) {
        | [] => failwith("Cannot handle empty list")
        | (t::ts) => {
          let (_, (x, _y)) =
            List.fold_left (fun ((i, acc), t) => {
                (add_int(i, 1i),
                  Curve.add_unsafe(
                    acc,
                    lookup(t, Array.get(params, i))) );
              }, (1i, lookup(t, Array.get(params, 0i) )), ts);
          x;
        }
      };
    };

    type three('a) =
      | Zero
      | One ('a)
      | Two ('a, 'a);

    let group3 = fun (xs) => {
      let default=0b;
      let (ts, r) =
        List.fold_left (fun ((ts, acc), x) => {
            switch (acc) {
              | Zero => (ts, One(x))
              | One(x0) => (ts, Two(x0, x))
              | Two(x0, x1) => ((x0, x1, x) :: ts, Zero)
            };
          },
          ([], Zero),
          xs
        );
      let ts =
        switch(r) {
          | Zero => ts
          | One(x0) => (x0, default, default) :: ts
          | Two(x0, x1) => (x0, x1, default) :: ts
        };
      List.rev(ts);
    };

    let digest_bits : Params.t -> list(boolean) -> field =
      fun (params, bs) => { digest(params, group3(bs)); };
  };
};
|meja}