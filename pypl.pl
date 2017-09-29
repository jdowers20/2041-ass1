#!/usr/bin/perl -w

sub getLineWhiteSpaces{
	my $line  = $_[0];
	my $whiteSpace = 0;
	while ($line =~ /^[ \t]/){
		if ($line =~ /^ /){
			$line =~ s/ //;
			$whiteSpace++;
		} else {
			$line =~ s/\t//;
			$whiteSpace++;
			while ($whiteSpace % 8){
				$whiteSpace++;
			}
		}
	}
	return $whiteSpace;
}

sub isFunct{
	my $name = $_[0];
	$name =~ s/\s//;
	#print("Looking for function '$name'\n");
	foreach my $func (@knownFuncts){
		if ($name eq $func){
			#print("'$name' found\n");
			return 1;
		}
	}
	#print("'$name' not found\n");
	return 0;
}

sub determineVariableType{
	my $name = $_[0];
	my $ass = $_[1];
	my $addToLists = $_[2];

	if (listExists($name) or $ass =~ /^\[.*\]/ or $ass =~ /^@/){
		if ($addToLists == 1){
			push(@listVars, $name);
		}
		return "@";
	} elsif (dictExists($name) or $ass =~ /^\{.*\}/ or $ass =~ /^%/){
		if ($addToLists == 1){
			push(@dictVars, $name);
		}
		return "%";
	} else {
		if ($addToLists == 1){
			push(@scalarVars, $name);
		}
		return "\$";
	}
}

sub dictExists{
	my $name = $_[0];
	#print("Looking for scalar '$name'\n");
	for my $var (@dictVars){
		if ($var eq $name){
			#print("'$name' found\n");
			return 1;
		}
	}
	#print("'$name' not found\n");
	return 0;
}

sub listExists{
	my $name = $_[0];
	#print("Looking for scalar '$name'\n");
	for my $var (@listVars){
		if ($var eq $name){
			#print("'$name' found\n");
			return 1;
		}
	}
	#print("'$name' not found\n");
	return 0;
}

sub scalarExists{
	my $name = $_[0];
	#print("Looking for scalar '$name'\n");
	for my $var (@scalarVars){
		if ($var eq $name){
			#print("'$name' found\n");
			return 1;
		}
	}
	#print("'$name' not found\n");
	return 0;
}

sub transformScalar{
	my $var = $_[0];
	if ($var eq "sys.stdin"){
		return "<STDIN>";
	} else {
		return "\$$var";
	}
}

sub transformFunctions{
	my $func = $_[0];
	#print ("function '$func'\n");
	if ($func =~ /^print/){
		my $end = "\\n";
		if ($func =~ /,\s*end='(.*?)'/){
			$func =~ s/,\s*end='(.*?)'//;
			$end = $1;
		}
		$func =~ s/\)\s*$//;
		$func = join("", $func, ", \"$end\")");
		return $func;
	} elsif($func =~ /^range/) {
		$func =~ /range\((.*?)\)/;
		my @args = split(/,/, $1, 2);
		if (defined $args[1]){
			my $upper = join("",$args[1],"-1");
			return "($args[0]..$upper)";
		} else {
			my $upper = join("",$args[0],"-1");
			return "(0..$upper)";
		}
	} elsif($func =~ /^sys\.stdout\.write/) {
		$func =~ s/sys\.stdout\.write/print/;
		return $func;
	} elsif($func =~ /^sys\.stdin\.readline/) {
		$func =~ s/sys\.stdin\.readline\(.*?\)/<STDIN>/;
		return $func;
	}
	return $func;
}

sub evaluateArguments{
	my $args = $_[0];
	#print("Args '$args'\n");
	$args =~ s/^\s*\(//;
	$args =~ s/\)\s*$//;
	#print("trimmed '$args'\n");
	my @argsList = split(/,/, $args);
	my $concat = "";
	foreach my $arg (@argsList) {
		if ($concat eq "") {
			$concat = evaluateExpressionLR($arg);
		} else {
			$concat = join(",", $concat, evaluateExpressionLR($arg));
		}
	}
	return "($concat)";
}

sub retrieveFunction{
	my $input = $_[0];
	#print("Getting function in '$input'\n");
	$input =~ /^([\w0-9\.]+)(\s*)\((.*)/;
	my $func = $1;
	my $space = $2;
	my $rem = $3;
	my @chars = split(//, $rem);
	#print("Chars '@chars'\n");

	my $args = "(";
	my $depth = 1;
	my $char = shift(@chars);
	while (defined $char){
		if ($char eq "("){
			$depth++;
		}elsif ($char eq ")"){
			$depth--;
		}
		$args = join("", $args, $char);
		if ($depth == 0){
			last;
		}
		$char = shift(@chars);
	}
	#print("Found function '",join("", $func, $space, $args), "' with rem '@chars'\n");
	return (join("", $func, $space, evaluateExpressionLR($args)), @chars);
}

sub evaluateExpressionLR{
	my $expr = $_[0];
	#print("Evaluating Expression '$expr'". "\n");
	if (!defined $expr){
		return "";
	}
	if ($expr eq ""){
		return "";
	}
	#print("Found Expression'$expr'\n");

	if ($expr =~ /^"/){
		$expr =~ /^("[^"]*")(.*)/;
		return join("", $1, evaluateExpressionLR($2));
	} elsif	($expr =~ /^(\(|\))/){
		$expr =~ /^(\(|\))(.*)/;
		if ($1 eq "("){return join("", "(", evaluateExpressionLR($2));}
		elsif ($1 eq ")"){return join("", ")", evaluateExpressionLR($2));}
		else{return join("", "", evaluateExpressionLR($2));}
		
	} elsif	($expr =~ /^[0-9\w]/){
		$expr =~ /^([0-9\w\.]+)/;
		my $word = $1;
		#print("Word '$word'\n");
		if (scalarExists($word) == 1){
			$expr =~ /^$word(.*)/;
			$word = transformScalar($word);
			return join("", "$word",evaluateExpressionLR($1));
		} elsif(isFunct($word) == 1){
			my @pack = retrieveFunction($expr);
			#print(join(":", ));
			my $funct = transformFunctions($pack[0]);
			return join("", "$funct",evaluateExpressionLR($pack[1]));
		} elsif ($word eq "and" or $word eq "or" or $word eq "and" ){
			$expr =~ /^$word(.*)/;
			return join("", $word, evaluateExpressionLR($1));
		} else {
			$expr =~ /^$word(.*)/;
			return join("", "$word", evaluateExpressionLR($1));
		}

	} elsif	($expr =~ /^(<=|<|>=|>|!=|==)/){
		my $comp = $1;
		$expr =~ /^$comp(.*)/;
		return join("", $comp, evaluateExpressionLR($1));
	} elsif	($expr =~ /^([\+\-\*\/\%]{1,2})/){
		my $oper = $1;
		my $escoper = join("", "\\", split(//, $oper));
		$expr =~ /^$escoper(.*)/;
		if ($oper eq "//"){$oper = "/";}
		return join("", $oper, evaluateExpressionLR($1));
	} elsif	($expr =~ /^(<<|>>|&|~)/){
		my $bitw = $1;
		$expr =~ /^$bitw(.*)/;
		return join("", $bitw, evaluateExpressionLR($1));
	} elsif	($expr =~  /(\^|\|)/){
		my $Bitw = $1;
		my $escBitw = join("", "\\", $Bitw);
		$expr =~ /^$escBitw(.*)/;
		return join("", $Bitw, evaluateExpressionLR($1));
	} elsif	($expr =~ /^,/){
		$expr =~ /^,(.*)/;
		return join("", ",", evaluateExpressionLR($1));
	} elsif	($expr =~ /^[\[\]]/){
		$expr =~ /^([\[\]])(.*)/;
		if ($1 eq "["){return join("", "(", evaluateExpressionLR($2));}
		elsif ($1 eq "]"){return join("", ")", evaluateExpressionLR($2));}
		else{return join("", "", evaluateExpressionLR($2));}
	} elsif	($expr =~ /^\s/){
		$expr =~ /^(\s+)(.*)/;
		return join("", $1, evaluateExpressionLR($2));
	} else {
		return $expr;
	}
	
}

sub generateWhiteSpace{
	my $count = $_[0];
	my $i = 0;
	my $space = "";
	while ($i < $count){
		$space = join("", $space, " ");
		$i++;
	}
	return $space;
}

sub evaluateLine{
	my $line = $_[0];
	my $indentLength = getLineWhiteSpaces($line);
	my $indent = generateWhiteSpace($indentLength);
	$line =~ s/^[\s]*//;
	$line =~ s/\n//;
	#print($line, "\n");

	if ($line =~ /^#/){
		#comment
		if ($line =~ /^#[^!]/){
			push (@output, "$line\n");
			return;
		}
		return;	
	}
	#determine if stack needs to be added to, or closed
	#print(join(", ", @stack), "\n");
	my $top = pop(@stack);
	while($top != $indentLength){
		if($top < $indentLength){
			#print("Outdenting at line $line\n");
			push(@stack, $top);
			$top = $indentLength;
		} elsif ($top > $indentLength){
			#print("Indenting at line $line\n");
			$top = pop(@stack);
			push(@output, join("", generateWhiteSpace($top), "}\n"));
		}
	}
	push(@stack, $top);

	#split line if needed
	if ($line =~ /;/){
		my @separators = $line =~ /[:;]/g;
		if ($separators[0] eq ";"){
			my @splitLines = split(/;/, $line,2);
			foreach my $splitLine (@splitLines){
				$splitLine =~ s/^[\s]*//;
				evaluateLine(join("", $indent, $splitLine));
			}
			return;
		}
	}

	if ($line =~ /^import/){
		return;
	} elsif ($line =~ /^(\w+)[ ]*=[ ]*(.*)$/){
		#assignment
		my $var = $1; 
		my $ass = evaluateExpressionLR($2);
		my $type = determineVariableType($var, $ass, 1);
		#print("Variable '$var' is type '$type'\n");
		push(@scalarVars, $var);
		push(@output, $indent,"$type$var = $ass;\n");
	} elsif ($line =~ /^(if|while)/) {
		$line =~ /(if|while)\s*([^:]*):\s*(.*)/;
		#print("Obtained from $1: condition '$2', and appendage '$3'\n");
		my $condition = evaluateExpressionLR($2);
		#print("Condition = '$condition'\n");
		push(@output, $indent,"$1($condition){\n");
		my $statements = $3;
		if (defined $statements and $statements =~ /[^\s]/){
			#print("Moving '$statements' to new line\n");
			evaluateLine(join("", $indent, "   ", $statements));
		}
	} elsif ($line =~ /^else/) {
		push(@output, $indent,"else {\n");
	} elsif ($line =~ /^for/) {
		$line =~ /^for ([\w0-9]+) in (.*?):\s*(.*)/;
		my $var = $1;
		my $set = $2;
		my $statements = $3;
		push(@scalarVars, $var);
		$set = evaluateExpressionLR($set);
		push(@output, $indent,"foreach \$$var ($set){\n");
		if (defined $statements and $statements =~ /[^\s]/){
			#print("Moving '$statements' to new line\n");
			evaluateLine(join("", $indent, "   ", $statements));
		}
	} elsif ($line =~ /^continue/) {
		push(@output, $indent,"next;\n");
	} elsif ($line =~ /^break/) {
		push(@output, $indent,"last;\n");
	} else {
		$line = evaluateExpressionLR($line);
		if ($line =~ /[^\s]/){
			push(@output, $indent,"$line;\n");
		}
	}
	#print ($line, "\n");
	#print(@output);

	return;
}

@scalarVars = ("sys.stdin");
@listVars = ();
@dictVars = ();
@output = ();
@stack = ();		# a record of the levels of indentation on the stack
@knownFuncts = ("print", "range", "len", "int", "sys.stdout.write", "sys.stdin.readline");

open($FILE, '<', $ARGV[0]);

push(@output, "#!/usr/bin/perl -w\n\n");

$first = 1;
while ($line = <$FILE>){
	if ($first == 1){
		push(@stack, getLineWhiteSpaces($line));
		$first = 0;
	}
	evaluateLine($line);
}
evaluateLine("\n");

print(@output);
