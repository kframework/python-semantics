require "python-semantics-boolean-ops.k"
require "python-semantics-slicing.k"
require "machine-integers.k"
require "unicode.k"

module PYTHON-SEMANTICS-STRINGS
  imports PYTHON-SEMANTICS-BOOLEAN-OPS
  imports PYTHON-SEMANTICS-SLICING
  imports MACHINE-INTEGERS
  imports UNICODE

  rule <k> invokeBuiltin(obj("add_str",_), ListItem(O:Object) ListItem(O2:Object), .) => test(istype(O2, ref("str")), strvalue(O) +String strvalue(O2), raiseInternal("TypeError", ("Can't convert '" + name(gettype(O2)) + "' object to str implicitly"))) ...</k>

  rule <k> invokeBuiltin(obj("eq_str",_), ListItem(O) ListItem(O2), .) => binaryOp(O, O2, "str", "str", bool(strvalue(O) ==String strvalue(O2))) ...</k>
  rule <k> invokeBuiltin(obj("ne_str",_), ListItem(O) ListItem(O2), .) => binaryOp(O, O2, "str", "str", bool(strvalue(O) =/=String strvalue(O2))) ...</k>

  rule [hash-str]: <k> invokeBuiltin(obj("hash_str",_), ListItem(O), .) => test(lengthString(strvalue(O)) ==Int 0, 0, accumulate(strvalue(O), (ordChar(substrString(strvalue(O), 0, 1)) <<Int 7) xorInt hashPrefix(Seed, Width), lengthString(strvalue(O)))) ...</k>
       <constants>... "PYTHONHASHSEED" |-> Seed "sys.hash_info.width" |-> Width ...</constants>

  rule invokeBuiltin(obj("str.__new__",_), ListItem(Cls:Object), .) => newHelper(Cls, ref("str"), .) ~> immutable("", Cls)
  rule invokeBuiltin(obj("str.__new__",_), ListItem(Cls:Object) ListItem(O:Object), .) => newHelper(Cls, ref("str"), .) ~> immutable(strvalue(getmember(O, "__str__", true, false, true)(.Arguments)), Cls)
  context immutable(strvalue(HOLE), _)

  rule invokeBuiltin(obj("str.__str__",_), ListItem(O), .) => strvalue(O)

  syntax ObjRef ::= accumulate(String, Int, Int)
  syntax Int ::= hashPrefix(Int, Int) [function]
               | hashSuffix(Int, Int) [function]

  rule hashSuffix(Seed, Width) => wrap(lcgRandom(Seed, Width /Int 4, Width) >>Int Width, Width)
  rule hashPrefix(Seed, Width) => wrap(lcgRandom(Seed, Width /Int 4, Width) &Int (2 ^Int Width -Int 1), Width)

  rule <k> accumulate((S:String => substrString(S, 1, lengthString(S))), (I:Int => (mult(Imag, I, Width) xorInt ordChar(substrString(S, 0, 1)))), _) ...</k>
       <constants>... "sys.hash_info.width" |-> Width "sys.hash_info.imag" |-> Imag ...</constants> when lengthString(S) =/=Int 0

  rule <k> accumulate("", I, Len:Int) => test((I xorInt Len xorInt hashSuffix(Seed, Width)) ==Int -1, -2, (I xorInt Len xorInt hashSuffix(Seed, Width))) ...</k>
       <constants>... "PYTHONHASHSEED" |-> Seed "sys.hash_info.width" |-> Width ...</constants>

  rule invokeBuiltin(obj("rpartition_str",_), ListItem(O) ListItem(Sep), .) => test(istype(Sep, ref("str")), #if rfindString(strvalue(O), strvalue(Sep), lengthString(strvalue(O))) ==Int -1 #then tuple("", "", strvalue(O)) #else tuple(substrString(strvalue(O), 0, rfindString(strvalue(O), strvalue(Sep), lengthString(strvalue(O)))), strvalue(Sep), substrString(strvalue(O), rfindString(strvalue(O), strvalue(Sep), lengthString(strvalue(O))) +Int lengthString(strvalue(Sep)), lengthString(strvalue(O)))) #fi, raiseInternal("TypeError", "Cannot convert object to str implicitly"))
  rule invokeBuiltin(obj("partition_str",_), ListItem(O) ListItem(Sep), .) => test(istype(Sep, ref("str")), #if findString(strvalue(O), strvalue(Sep), 0) ==Int -1 #then tuple(strvalue(O), "", "") #else tuple(substrString(strvalue(O), 0, findString(strvalue(O), strvalue(Sep), 0)), strvalue(Sep), substrString(strvalue(O), findString(strvalue(O), strvalue(Sep), 0) +Int lengthString(strvalue(Sep)), lengthString(strvalue(O)))) #fi, raiseInternal("TypeError", "Cannot convert object to str implicitly"))

  rule invokeBuiltin(obj("ord",_), ListItem(O), .) => test(istype(O, ref("str")), test(length(strvalue(O), UTF-8) =/=Int 1, raiseInternal("TypeError", "ord() expected a character, but string of length " +String Int2String(length(strvalue(O), UTF-8)) +String " found"), codePoint(strvalue(O), UTF-8, 0)), raiseInternal("TypeError", "ord() expected string of length 1"))

  rule invokeBuiltin(obj("len_str",_), ListItem(O), .) => length(strvalue(O), UTF-8)

  rule invokeBuiltin(obj("rsplit_str",_), ListItem(O:Object), .) => ref("rsplit_str")(O, ref("None"), -1)
  rule invokeBuiltin(obj("rsplit_str",_), ListItem(O:Object) ListItem(Sep:Object), .) => ref("rsplit_str")(O, Sep, -1)
  rule invokeBuiltin(obj("rsplit_str",_), ListItem(O:Object) ListItem(Sep:Object) ListItem(MaxSplit:Object), .) => if Sep is ref("None") : rsplit(strvalue(O), ref("index")(MaxSplit)) else: test(istype(Sep, ref("str")), rsplit(strvalue(O), ref("index")(MaxSplit), strvalue(Sep)), raiseInternal("TypeError", "Cannot convert object to str implicitly"))

  syntax ObjRef ::= rsplit(Exp, Exp) [strict]
                  | rsplit(Exp, Exp, String) [strict(1, 2)]

  rule rsplit(S:Object, MaxSplit:Object, Sep:String) => test(intvalue(MaxSplit) ==Int 0, [S], test(rfindString(strvalue(S), Sep, lengthString(strvalue(S))) ==Int -1, [strvalue(S)], rsplit(ref("rpartition_str")(strvalue(S), Sep)[0], intvalue(MaxSplit) -Int 1, Sep) + [ref("rpartition_str")(strvalue(S), Sep)[2]]))
  //TODO: rsplit(None, ...)

  rule invokeBuiltin(obj("format_str",_), ListItem(Format) L:List, M:Map) => format(strvalue(Format), tuple(DeListify(L)), {DeMapify(M)}, .K)

  syntax ObjRef ::= format(String, Exp, Exp, K) [strict(2, 3)]
                  | formatField(String, String, Object, Object, K)
                  | lookupField(String, String, String, Object, Object, K)
                  | lookupField(String, K, String, String, Object, Object, K) [strict(2)]
                  | convertField(Object, String)
                  | checkFormat(Exp) [strict]
  syntax K ::= lookupArgName(String)
             | lookupElementIndex(String, Object) [function]

  syntax Int ::= "notFound"
  rule notFound +Int I:Int => notFound [simplification]
  rule notFound -Int I:Int => notFound [simplification]
  rule notFound ==Int notFound => true [simplification]
  rule notFound ==Int I:#Int => false [simplification]
  rule I:#Int ==Int notFound => false [simplification]
  rule minInt(notFound, I:Int) => I [simplification]
  rule minInt(I:Int, notFound) => I [simplification] 
  rule substrString(S, notFound, _) => "" [simplification]
  rule substrString(S, Start, notFound) => substrString(S, Start, lengthString(S)) [simplification]

  syntax Int ::= findCharsInString(String, String, Int) [function]
  rule findCharsInString(S, Pattern, I) => minInt(#if findString(S, substrString(Pattern, 0, 1), I) ==Int -1 #then notFound #else findString(S, substrString(Pattern, 0, 1), I) #fi, findCharsInString(S, substrString(Pattern, 1, lengthString(Pattern)), I)) when Pattern =/=String ""
  rule findCharsInString(S, "", _) => notFound

  rule format(Format, L, M, IsAuto) => substrString(Format, 0, findCharsInString(Format, "{}", 1)) + format(substrString(Format, findCharsInString(Format, "{}", 1), lengthString(Format)), L, M, IsAuto) when substrString(Format, 0, 1) =/=String "{" andBool substrString(Format, 0, 1) =/=String "}" andBool Format =/=String ""
  rule format("", _, _, _) => ""
  rule format(Format, L, M, IsAuto) => raiseInternal("ValueError", "single '}' encountered in format string") when substrString(Format, 0, 1) ==String "}" andBool substrString(Format, 0, 2) =/=String "}}"
  rule format(Format, L, M, IsAuto) => "{" + format(substrString(Format, 2, lengthString(Format)), L, M, IsAuto) when substrString(Format, 0, 2) ==String "{{"
  rule format(Format, L, M, IsAuto) => "}" + format(substrString(Format, 2, lengthString(Format)), L, M, IsAuto) when substrString(Format, 0, 2) ==String "}}"
  rule format(Format, L, M, IsAuto) => raiseInternal("ValueError", "unmatched '{' in format") when substrString(Format, 0, 1) ==String "{" andBool substrString(Format, findCharsInString(Format, "{}", 1), findCharsInString(Format, "{}", 1) +Int 1) ==String "{"
  rule format(Format, L, M, IsAuto) => raiseInternal("ValueError", "single '{' encountered in format string") when substrString(Format, 0, 1) ==String "{" andBool findCharsInString(Format, "{}", 1) ==Int notFound
  rule format(Format, L:Object, M:Object, IsAuto) => formatField(substrString(Format, 1, findCharsInString(Format, "{}", 1)), substrString(Format, findCharsInString(Format, "{}", 1) +Int 1, lengthString(Format)), L, M, IsAuto) when substrString(Format, 0, 1) ==String "{" andBool substrString(Format, findCharsInString(Format, "{}", 1), findCharsInString(Format, "{}", 1) +Int 1) ==String "}"

  rule formatField(Field, Format, L, M, IsAuto) => lookupField(substrString(Field, 0, findCharsInString(Field, "!:", 0)), Field, Format, L, M, IsAuto)

  rule lookupField(FieldName, Field, Format, L, M, IsAuto) => lookupField(substrString(FieldName, findCharsInString(FieldName, ".[", 0), lengthString(FieldName)), lookupArgName(substrString(FieldName, 0, findCharsInString(FieldName, ".[", 0))), Field, Format, L, M, IsAuto)
  rule [format-getattr]: lookupField(FieldName, O:Object, Field, Format, L, M, IsAuto) => lookupField(substrString(FieldName, findCharsInString(FieldName, ".[", 1), lengthString(FieldName)), ref("getattr")(O, substrString(FieldName, 1, findCharsInString(FieldName, ".[", 1))), Field, Format, L, M, IsAuto) when substrString(FieldName, 0, 1) ==String "."
  rule [format-getitem]: lookupField(FieldName, O:Object, Field, Format, L, M, IsAuto) => lookupField(substrString(FieldName, findCharsInString(FieldName, "]", 1) +Int 1, lengthString(FieldName)), lookupElementIndex(substrString(FieldName, 1, findCharsInString(FieldName, "]", 1)), O), Field, Format, L, M, IsAuto) when substrString(FieldName, 0, 1) ==String "["

  context lookupField(_, HOLE, _, _, _, _, _) when isExp(HOLE)

  rule lookupField(_, lookupArgName(""), _, _, _, _, -1) => raiseInternal("ValueError", "cannot switch from manual field specification to automatic field numbering")
  rule [auto-to-manual]: lookupField(_, lookupArgName(ArgName), _, _, _, _, I) => raiseInternal("ValueError", "cannot switch from automatic field numbering to manual field specification") when I >=Int 0 andBool isInt(String2Int(ArgName))
  rule lookupField(_, (lookupArgName("") => L[#if IsAuto ==K .K #then 0 #else IsAuto #fi]), _, _, L, _, (IsAuto => #if IsAuto ==K .K #then 1 #else IsAuto +Int 1 #fi)) when IsAuto =/=K -1
  rule lookupField(_, (lookupArgName(ArgName) => L[String2Int(ArgName)]), _, _, L, _, (IsAuto => -1)) when (IsAuto ==K -1 orBool IsAuto ==K .K) andBool isInt(String2Int(ArgName))
  rule lookupField(_, (lookupArgName(ArgName) => M[ArgName]), _, _, _, M, _) when isInt(String2Int(ArgName)) =/=K true

  rule lookupElementIndex(ElementIndex, O) => O[String2Int(ElementIndex)] when isInt(String2Int(ElementIndex))
  rule lookupElementIndex(ElementIndex, O) => O[ElementIndex] when isInt(String2Int(ElementIndex)) =/=K true

  rule lookupField(_, O:Object, Field, Format, L, M, IsAuto) => ref("format")(convertField(O, substrString(Field, findCharsInString(Field, ":!", 0), findCharsInString(Field, ":!", 0) +Int 3)), substrString(Field, findCharsInString(Field, ":", 0) +Int 1, lengthString(Field))) + format(Format, L, M, IsAuto)

  rule convertField(O:Object, Conversion) => ref("str")(O) when Conversion ==String "!s" orBool Conversion ==String "!s:"
  rule convertField(O:Object, Conversion) => ref("repr")(O) when Conversion ==String "!r" orBool Conversion ==String "!r:"
  rule convertField(O:Object, Conversion) => ref("ascii")(O) when Conversion ==String "!a" orBool Conversion ==String "!a:"
  rule convertField(O:Object, Conversion) => O when Conversion ==String "" orBool substrString(Conversion, 0, 1) ==String ":"
  rule convertField(O:Object, Conversion) => raiseInternal("ValueError", "unknown conversion specifier" +String substrString(Conversion, 1, 2)) when substrString(Conversion, 0, 1) ==String "!" andBool (substrString(Conversion, 2, 3) ==String ":" orBool lengthString(Conversion) ==Int 2)
  rule convertField(O:Object, Conversion) => raiseInternal("ValueError", "expected ':' after format specifier") when substrString(Conversion, 0, 1) ==String "!" andBool (substrString(Conversion, 1, 2) ==String "s" orBool substrString(Conversion, 1, 2) ==String "r" orBool substrString(Conversion, 1, 2) ==String "a") andBool substrString(Conversion, 2, 3) =/=String "" andBool substrString(Conversion, 2, 3) =/=String ":"

  rule invokeBuiltin(obj("format",_), ListItem(O:Object), .) => ref("format")(O, "")
  rule invokeBuiltin(obj("format",_), ListItem(O:Object) ListItem(Format:Object), .) => checkFormat(getmember(O, "__format__", true, false, true)(Format))
  rule checkFormat(O:Object) => test(istype(O, ref("str")), O, raiseInternal("TypeError", "__format__ method did not return string"))

  rule invokeBuiltin(obj("format_object",_), ListItem(O:Object) ListItem(Format:Object), .) => getmember(ref("str")(O), "__format__", true, false, true)(Format)

  syntax FormatSpec ::= parseFormatSpec(String) [function]
                      | parseFormatSpec(String, String) [function]
                      | parseFormatSpec(String, String, String) [function]
                      | parseFormatSpec(String, String, String, String) [function]
                      | parseFormatSpec(String, String, String, String, String) [function]
                      | parseFormatSpec(String, String, String, String, String, String) [function]
                      | parseFormatSpec(String, String, String, String, String, String, String) [function]
                      | parseFormatSpec(String, String, String, String, String, String, String, String) [function]
                      | formatSpec(String, String, String, String, String, String, String, String)
                      | "invalidFormatSpec"

  syntax ObjRef ::= doFormatStr(String, FormatSpec)

  rule invokeBuiltin(obj("__format___str",_), ListItem(O:Object) ListItem(Format:Object), .) => doFormatStr(strvalue(O), parseFormatSpec(strvalue(Format)))
  rule parseFormatSpec(Format) => #if substrString(Format, 1, 2) =/=String "<" andBool substrString(Format, 1, 2) =/=String ">" andBool substrString(Format, 1, 2) =/=String "=" andBool substrString(Format, 1, 2) =/=String "^" #then parseFormatSpec("", Format) #else parseFormatSpec(substrString(Format, 0, 1), substrString(Format, 1, lengthString(Format))) #fi
  rule parseFormatSpec(Fill, Format) => #if substrString(Format, 0, 1) ==String "<" orBool substrString(Format, 0, 1) ==String ">" orBool substrString(Format, 0, 1) ==String "=" orBool substrString(Format, 0, 1) ==String "^" #then parseFormatSpec(Fill, substrString(Format, 0, 1), substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, "", Format) #fi
  rule parseFormatSpec(Fill, Align, Format) => #if substrString(Format, 0, 1) ==String "+" orBool substrString(Format, 0, 1) ==String "-" orBool substrString(Format, 0, 1) ==String " " #then parseFormatSpec(Fill, Align, substrString(Format, 0, 1), substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, Align, "", Format) #fi
  rule parseFormatSpec(Fill, Align, Sign, Format) => #if substrString(Format, 0, 1) ==String "#" #then parseFormatSpec(Fill, Align, Sign, "#", substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, Align, Sign, "", Format) #fi
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Format) => #if substrString(Format, 0, 1) ==String "0" #then parseFormatSpec(#if Fill ==String "" #then "0" #else Fill #fi, #if Align ==String "" #then "=" #else Align #fi, Sign, AltForm, "", substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, Align, Sign, AltForm, "", Format) #fi
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Width, Format) => parseFormatSpec(Fill, Align, Sign, AltForm, Width +String substrString(Format, 0, 1), substrString(Format, 1, lengthString(Format))) when ordChar(substrString(Format, 0, 1)) >=Int 48 andBool ordChar(substrString(Format, 0, 1)) <=Int 57
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Width, Format) => #if substrString(Format, 0, 1) ==String "," #then parseFormatSpec(Fill, Align, Sign, AltForm, Width, ",", substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, Align, Sign, AltForm, Width, "", Format) #fi when ordChar(substrString(Format, 0, 1)) <Int 48 orElseBool ordChar(substrString(Format, 0, 1)) >Int 57 orElseBool Format ==String ""
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, Format) => #if substrString(Format, 0, 1) ==String "." #then parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, ".", substrString(Format, 1, lengthString(Format))) #else parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, "", Format) #fi
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, Precision, Format) => parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, Precision +String substrString(Format, 0, 1), substrString(Format, 1, lengthString(Format))) when ordChar(substrString(Format, 0, 1)) >=Int 48 andBool ordChar(substrString(Format, 0, 1)) <=Int 57 andBool lengthString(Precision) >Int 0
  rule parseFormatSpec(Fill, Align, Sign, AltForm, Width, Thousands, Precision, Format) => formatSpec(Fill, Align, Sign, AltForm, Width, Thousands, Precision, Format) when (ordChar(substrString(Format, 0, 1)) <Int 48 orElseBool ordChar(substrString(Format, 0, 1)) >Int 57 orElseBool lengthString(Precision) ==Int 0 orElseBool Format ==String "") andBool lengthString(Format) <=Int 1
  rule parseFormatSpec(_, _, _, _, _, _, Precision, Format) => invalidFormatSpec when (ordChar(substrString(Format, 0, 1)) <Int 48 orBool ordChar(substrString(Format, 0, 1)) <Int 48 orBool ordChar(substrString(Format, 0, 1)) >Int 57 orBool lengthString(Precision) ==Int 0) andBool lengthString(Format) >Int 1

  rule doFormatStr(_, invalidFormatSpec) => raiseInternal("ValueError", "Invalid format specifier")
  rule doFormatStr(_, formatSpec(_, "=", _, _, _, _, _, _)) => raiseInternal("ValueError", "'=' alignment not allowed in string format specifier")
  rule doFormatStr(_, formatSpec(_, _, Sign, _, _, _, _, _)) => raiseInternal("ValueError", "Sign not allowed in string format specifier") when Sign =/=String ""
  rule doFormatStr(_, formatSpec(_, _, _, "#", _, _, _, _)) => raiseInternal("ValueError", "Alternate form (#) not allowed in string format specifier")
  rule doFormatStr(_, formatSpec(_, _, _, _, _, ",", _, _)) => raiseInternal("ValueError", "Cannot specify ',' with 's'")
  rule doFormatStr(_, formatSpec(_, _, _, _, _, _, ".", _)) => raiseInternal("ValueError", "Format specifier missing precision")
  rule doFormatStr(_, formatSpec(_, _, _, _, _, _, _, Type)) => raiseInternal("ValueError", "Unknown format code '" +String Type +String "' for string object") when Type =/=String "s" andBool Type =/=String ""
  rule doFormatStr(S, formatSpec(Fill, Align, "", "", Width, "", Precision, Type)) => alignString(#if Precision ==String "" #then S #else substrString(S, 0, String2Int(substrString(Precision, 1, lengthString(Precision)))) #fi, #if Fill ==String "" #then " " #else Fill #fi, #if Align ==String "" #then "<" #else Align #fi, #if Width ==String "" #then 0 #else String2Int(Width) #fi) when (Type ==String "s" orBool Type ==String "") andBool Align =/=String "="

  syntax String ::= alignString(String, String, String, Int) [function]

  rule alignString(S, Fill, "<", Width) => #if lengthString(S) >=Int Width #then S #else S +String (Fill *String (Width -Int lengthString(S))) #fi
  rule alignString(S, Fill, ">", Width) => #if lengthString(S) >=Int Width #then S #else (Fill *String (Width -Int lengthString(S))) +String S #fi
  rule alignString(S, Fill, "^", Width) => #if lengthString(S) >=Int Width #then S #else (Fill *String ((Width -Int lengthString(S)) /Int 2)) +String S +String (Fill *String ((Width -Int lengthString(S)) /Int 2 +Int (Width -Int lengthString(S)) %Int 2)) #fi

  rule invokeBuiltin(obj("startswith_str",_), ListItem(S:Object) ListItem(Prefix:Object), .) => test(istype(Prefix, ref("str")), startswith(strvalue(S), Prefix), test(istype(Prefix, ref("tuple")), startswith(strvalue(S), listvalue(Prefix)), raiseInternal("TypeError", "startswith first arg must be str or tuple of str")))
  rule invokeBuiltin(obj("startswith_str",_), ListItem(S:Object) ListItem(Prefix:Object) ListItem(Start:Object), .) => ref("startswith_str")(S, Prefix, Start, lengthString(strvalue(S)))
  rule invokeBuiltin(obj("startswith_str",_), ListItem(S:Object) ListItem(Prefix:Object) ListItem(Start:Object) ListItem(End:Object), .) => ref("startswith_str")(S[Start : End : ], Prefix)

  syntax Exp ::= startswith(String, Exp) [strict(2)]
  syntax Exp ::= startswith(String, List)

  rule startswith(S:String, Prefix:Object) => test(istype(Prefix, ref("str")), #if findString(S, strvalue(Prefix), 0) ==Int 0 #then ref("True") #else ref("False") #fi, raiseInternal("TypeError", "Cannot convert object to str implicitly"))
  rule startswith(S:String, ListItem(ref(N)) L:List) => startswith(S, ref(N)) or startswith(S, L)
  rule startswith(S:String, .List) => ref("False")

  //TODO: fix ref(id()). We need this right now because if I pass an object then strictness will refuse to heat because it's already a KResult. Need to wait for improved heating/cooling
  rule invokeBuiltin(obj("getitem_str",_), ListItem(S:Object) ListItem(Item:Object), .) => test(istype(Item, ref("slice")), reduce(slice(S, Item), "", '_+_), getitemString(strvalue(S), ref(id(Item))))

  syntax Exp ::= getitemString(String, Exp)
  rule getitemString(S, E:Exp) => ref("index")(E) ~> getitemString(S, HOLE) when isInt(E) =/=K true [heat]
  rule O:Object ~> getitemString(S, HOLE) => getitemString(S, intvalue(O)) [cool]
  rule getitemString(S:String, I:Int) => test(I >=Int 0 -Int length(S, UTF-8) andBool I <Int length(S, UTF-8), test(I >=Int 0, bytes(S, UTF-8, I), bytes(S, UTF-8, I +Int length(S, UTF-8))), raiseInternal("IndexError", "string index out of range"))

  rule invokeBuiltin(obj("str.__mul__",_), ListItem(S) ListItem(I), .) => multiplyString(strvalue(S), ref(id(I)))
  rule invokeBuiltin(obj("str.__rmul__",_), ListItem(S) ListItem(I), .) => multiplyString(strvalue(S), ref(id(I)))
  syntax Exp ::= multiplyString(String, Exp)
  rule multiplyString(S, E:Exp) => ref("index")(E) ~> multiplyString(S, HOLE) when isInt(E) =/=K true [heat]
  rule O:Object ~> multiplyString(S, HOLE) => multiplyString(S, intvalue(O)) [cool]
  rule multiplyString(S:String, I:Int) => S *String I

  rule invokeBuiltin(obj("join_str",_), ListItem(S) ListItem(L), .) => joinString(strvalue(S), iterate(L, .))
  //this is a bit dumb of a structure, but oh well
  syntax String ::= joinString(String, Exp) [strict(2)]
  syntax String ::= joinString2(String, Exp, String) [function]
  rule joinString(S, list(L:List)) => joinString2(S, list(L:List), "")
  rule joinString2(S, list(ListItem(O) ListItem(O2) L:List), S2) => test(istype(O, ref("str")), joinString2(S, list(ListItem(O2) L), S2 +String strvalue(O) +String S), raiseInternal("TypeError", "expected str instance as sequence item"))
  rule joinString2(_, list(ListItem(O)), S) => test(istype(O, ref("str")), S +String strvalue(O), raiseInternal("TypeError", "expected str instance as sequence item"))
  rule joinString2(_, list(.), S) => S

  rule invokeBuiltin(obj("repr",_), ListItem(S), .) => checkRepr(getmember(S, "__repr__", true, false, true) (.Arguments))
  syntax Exp ::= checkRepr(Exp) [strict]
  rule checkRepr(O:Object) => test(istype(O, ref("str")), O, raiseInternal("TypeError", "__repr__ returned non-string"))

  rule invokeBuiltin(obj("str.__repr__",_), ListItem(S), .) => reprString(strvalue(S), #if findString(strvalue(S), "'", 0) =/=Int -1 andBool findString(strvalue(S), "\"", 0) ==Int -1 #then "\"" #else "'" #fi)
  syntax String ::= reprString(String, String) [function]
  rule reprString(S, Quote) => Quote +String reprString2(S, Quote) +String Quote
  syntax String ::= reprString2(String, String) [function]
  rule reprString2(S, Quote) => reprString3(bytes(S, UTF-8, 0), Quote) +String reprString2(substrString(S, lengthString(bytes(S, UTF-8, 0)), lengthString(S)), Quote) when S =/=String ""
  rule reprString2("", _) => ""
  syntax String ::= reprString3(String, String) [function]
  rule reprString3(Quote, Quote) => "\\" +String Quote
  rule reprString3("\\", _) => "\\\\"
  rule reprString3("\t", _) => "\\t"
  rule reprString3("\n", _) => "\\n"
  rule reprString3("\r", _) => "\\r"
  rule reprString3(S, Quote) => reprString4(codePoint(S, UTF-8, 0), S) when S =/=String Quote andBool S =/=String "\\" andBool S =/=String "\t" andBool S =/=String "\n" andBool S =/=String "\r"
  syntax String ::= reprString4(Int, String) [function]
  rule reprString4(CodePoint, _) => "\\x" +String Int2Hex(CodePoint, 2) when CodePoint <Int 32 orBool CodePoint ==Int 127
  rule reprString4(CodePoint, S) => S when CodePoint >=Int 32 andBool CodePoint <Int 127

  // these are commented out because we don't want to implement isPrintable yet because that would
  // require access to the Unicode character database. For now it's fine because I don't intend to
  // use unicode characters in any of the relevant strings.

  //rule reprString4(CodePoint, S) => S when CodePoint >Int 127 andBool isPrintable(CodePoint)
  //rule reprString4(CodePoint, _) => "\\x" +String Int2Hex(CodePoint, 2) when CodePoint >Int 127 andBool CodePoint <Int 256 andBool notBool isPrintable(CodePoint)
  //rule reprString4(CodePoint, _) => "\\u" +String Int2Hex(CodePoint, 4) when CodePoint >=Int 256 andBool CodePoint <Int 65536 andBool notBool isPrintable(CodePoint)
  //rule reprString4(CodePoint, _) => "\\U" +String Int2Hex(CodePoint, 8) when CodePoint >=Int 65536 andBool notBool isPrintable(CodePoint)


endmodule
