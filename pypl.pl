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
	#print ("IsFucnt '$name'\n");
	foreach my $func (@knownFuncts){
		if ($name eq $func){
			return 1;
		}
	}
	if ($name =~ /(.*?)\.(append|pop)/ and varExists($1) eq "\@"){
		return 1;
	}
	if ($name =~ /(.*?)\.(keys)/ and varExists($1) eq "\%"){
		return 1;
	}
	if ($name =~ /(.*?)\.(join|split)/){
		return 1;
	}
	return 0;
}

sub determineVariableType{
	my $name = $_[0];
	my $ass = $_[1];
	my $addToLists = $_[2];

	if ($name =~ /.*?\[.*?\]/){
		if ($addToLists == 1){
			push(@scalarVars, $name);
		}
		return "\$";
	}
	if ($ass =~ /^(sort|split)/){
		if ($addToLists == 1){
			push(@listVars, $name);
		}
		return "\@";
	}

	if (varExists($name) eq "\@" or $ass =~ /^\(.*\)/ or $ass =~ /^\@/){
		if ($addToLists == 1){
			push(@listVars, $name);
		}
		return "\@";
	} elsif (varExists($name) eq "\%" or $ass =~ /^\{.*\}/ or $ass =~ /^\%/){
		if ($addToLists == 1){
			push(@dictVars, $name);
		}
		return "\%";
	} else {
		if ($addToLists == 1){
			push(@scalarVars, $name);
		}
		return "\$";
	}
}

sub varExists{
	my $name = $_[0];
	$name =~ s/\[.*?\]//;
	$name =~ s/\{.*?\}//;
	#print ("Var name '$name'\n");
	for my $var (@dictVars){
		if ($var eq $name){
			return "\%";
		}
	}
	for my $var (@listVars){
		if ($var eq $name){
			return "\@";
		}
	}
	for my $var (@scalarVars){
		if ($var eq $name){
			return "\$";
		}
	}
	return 0;
}

sub transformVar{
	my $var = $_[0];
	my $type = determineVariableType($var, "", 0);

	if ($type eq "\%"){
		return "\%$var";
	} elsif ($type eq "\@"){
		return transformList($var);
	} else {
		return transformScalar($var);
	}
}

sub transformList{
	my $var = $_[0];

	if ($var =~ /sys.argv/){
		$var = "ARGV";
	}

	return "\@$var";
}

sub transformScalar{
	my $var = $_[0];
	if ($var eq "sys.stdin"){
		return "<STDIN>";
	} elsif($var =~ /(.*?)\[(.*?)\]/) {
		my $name = $1;
		my $par = evaluateExpressionLR($2);
		if (determineVariableType($name, "", 0) eq "\%"){
			return "\$$name\{$par\}";
		} else{
			if ($name eq "sys.argv"){
				$name = "ARGV";
				$par = "$par -1";
				if ($par =~ /:/){
					$par =~ s/:/ -1:/;
				}
			}
			if ($par =~ /(.*?):(.*)/){
				my $first = $1;
				my $second = $2;
				if ($first =~ /^\s*( -1|)$/){
					$first =~ s/\s*( -1|)/0$1/;
				}
				if ($second =~ /^\s*( -1)?$/){
					$second =~ s/^\s*( -1)?$/\$#$name/;
				}
				push(@output, $indent, "\@tmpList = \@$name\[($first..$second)\];\n");
				return "\@tmpList";
			}				
			return "\$$name\[$par\]";
		}
	} else {
		return "\$$var";
	}
}

sub transformFunctions{
	my $func = $_[0];
	#print ("function '$func'\n");
	if ($func =~ /^print/){
		if ($func =~ /^print\s*\(\s*\)/){
			return "print(\"\\n\")";
		}
		my $end = "\"\\n\"";
		if ($func =~ /,\s*end\s*=\s*(.*?)\)/){
			$func =~ s/,\s*end\s*=\s*(.*?)\)//;
			$end = evaluateExpressionLR($1);
		}
		$func =~ s/\)\s*$//;
		$func = join("", $func, ", $end)");
		return $func;
	} elsif($func =~ /^range/) {
		$func =~ /range\((.*)/;
		my $pars =  $1;
		$pars =~ s/\)\s*$//;
		#print("Range pars '$pars'\n");
		my @args = split(/,/, $pars, 2);
		#print("Args '",join(":", @args), "'\n");
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
	} elsif($func =~ /^sorted\s*\((.*)/) {
		my $par = $1;
		$par =~ s/\)\s*$//;
		$par = evaluateExpressionLR($par);
		return "sort($par)";
	} elsif($func =~ /^sys\.stdin\.readline\(/) {
		$func =~ s/sys\.stdin\.readline\(.*?\)/<STDIN>/;
		return $func;
	} elsif($func =~ /^sys\.stdin\.readlines/) {
		push(@output, "$indent","while(\$tmpLineReader = <STDIN>){\n");
		push(@output, "$indent","   chomp(\$tmpLineReader);\n");
		push(@output, "$indent","   push(\@tmpLines, \$tmpLineReader);\n");
		push(@output, "$indent","}\n");
		$func = "\@tmpLines";
		return $func;
	} elsif($func =~ /(.*?)\.append\((.*)/){
		my $list = $1;
		my $app = $2;
		$app =~s/\)\s*$//;
		$app = evaluateExpressionLR($app);
		return "push(\@$list, $app)"
	} elsif($func =~ /(.*?)\.keys\(\)/){
		my $dict = $1;
		#print("Dict '$dict'\n");
		return "keys($dict)";
	} elsif($func =~ /(.*?)\.pop\((.*?)\)/){
		my $list = $1;
		my $index = $2;
		if ($index eq ""){
			$index = "-1";
		} else {
			$index = evaluateExpressionLR($index);
		}
		return "splice(\@$list, $index)"
	} elsif($func =~ /len\((.*)/){
		my $par = $1;
		$par =~ s/\)\s*$//;
		$par = evaluateExpressionLR($par);
		if ($par =~ /\@(.*)?/){
			if ($1 eq "ARGV"){
				$par = "$par +1";
			}
			return "scalar $par";
		} else {
			return "length($par)";
		}
	} elsif($func =~ /(.*?)\.split\((.*?)/){
		my $prefix = $1;
		my $par = $2;
		$par =~ s/\)\s*$//;
		if ($par =~ /["'](.*?)["']/){
			return join("", "split(/$1/, ",evaluateExpressionLR($prefix),")");
		} else{
			return join("", "split(/ /, ",evaluateExpressionLR($prefix),")");
		}
	} elsif($func =~ /(.*?)\.join\((.*)/){
		my $prefix = $1;
		my $par = $2;
		$par =~ s/\)\s*$//;
		return join("", "join($prefix, ",evaluateExpressionLR($par),")");
	}
	return $func;
}

sub retrieveFunction{
	my $input = $_[0];
	#print("Getting function in '$input'\n");
	$input =~ /^((["'].*?["'])?[\w0-9\.]+)(\s*)\((.*)/;
	my $func = $1;
	my $space = $3;
	my $rem = $4;
	#print("Found func '$func', space '$space', rem '$rem' \n");
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
	if (!defined $expr){
		return "";
	}
	if ($expr eq ""){
		return "";
	}
	#print("Found Expression'$expr'\n");

	if ($expr =~ /^["']/){
		$expr =~ /^("[^"]*"|'[^']*')(\s*%\s*\(.*?\))?(.*)/;
		my $str = $1;
		my $format = $2;
		my $rem = $3;
		#print("String '$str', '$format', rem '$rem'\n");
		if (defined $format and $format ne ""){
			$format =~ s/\s*%\s*\(/\(/;
			$format = evaluateExpressionLR($format);
			return join("", "sprintf($str, $format)", $rem)
		} else {
			if($rem =~ /\.(split|join)/){
				my @pack = retrieveFunction($expr);
				my $funct = transformFunctions(shift(@pack));
				return join("", "$funct",evaluateExpressionLR(join("",@pack)));
			}
			return join("", $str, evaluateExpressionLR($rem));
		}
	} elsif ($expr =~ /^r"/){
		$expr =~ /^r("[^"]*")(.*)/;
		my $str = $1;
		my $rem = evaluateExpressionLR($2);
		return join("", $str, $rem);
	} elsif	($expr =~ /^(\(|\))/){
		$expr =~ /^(\(|\))(.*)/;
		if ($1 eq "("){return join("", "(", evaluateExpressionLR($2));}
		elsif ($1 eq ")"){return join("", ")", evaluateExpressionLR($2));}
		else{return join("", "", evaluateExpressionLR($2));}
		
	} elsif	($expr =~ /^[0-9\w]/){
		$expr =~ /^([0-9\w\.]+(\[.*?\])*)+/;
		my $word = $1;
		#print("Found Word '$word'\n");
		my $escWord = $word;
		$escWord =~ s/([\.\[\]])/\\$1/g;
		#print("Word '$word'\n");
		if (varExists($word)){
			#print("Found var '$word'\n");
			$expr =~ /^$escWord(.*)/;
			my $rem = $1;
			$word = transformVar($word);
			#print("Var is '$word'\n");
			return join("", "$word",evaluateExpressionLR($rem));
		} elsif(isFunct($word) == 1){
			#print("Found function\n");
			my @pack = retrieveFunction($expr);
			my $funct = transformFunctions(shift(@pack));
			return join("", "$funct",evaluateExpressionLR(join("",@pack)));
		} elsif ($word eq "and" or $word eq "or" or $word eq "and" ){
			$expr =~ /^$escWord(.*)/;
			return join("", $word, evaluateExpressionLR($1));
		} else {
			$expr =~ /^$escWord(.*)/;
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
		if ($bitw eq "~"){
			$expr =~ /^~([0-9\w\.\[\]]+)(.*)/;
			my $var = $1;
			my $rem = $2;
			#print("~ '$var', '$rem'\n");
			return join("", "-",evaluateExpressionLR($var),"-1",evaluateExpressionLR($rem));
		}
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
		my $space = $1;
		return join("", $space, evaluateExpressionLR($2));
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
	$indent = generateWhiteSpace($indentLength);
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
		if ($ass eq "\{\}"){return;}
		#print("Variable '$var' is type '$type'\n");
		push(@output, $indent,"$type$var = $ass;\n");
	} elsif ($line =~ /^(if|while|elif)/) {
		$line =~ /(if|while|elif)\s*([^:]*):\s*(.*)/;
		#print("Obtained from $1: condition '$2', and appendage '$3'\n");
		my $type = $1;
		if ($type eq "elif"){$type = "elsif"}
		my $condition = evaluateExpressionLR($2);
		my $statements = $3;
		#print("Condition = '$condition'\n");
		push(@output, $indent,"$type($condition){\n");
		if (defined $statements and $statements =~ /[^\s]/){
			#print("Moving '$statements' to new line\n");
			evaluateLine(join("", $indent, "   ", $statements));
		}
	} elsif ($line =~ /^else/) {
		push(@output, $indent,"else {\n");
	} elsif ($line =~ /^for/) {
		$line =~ /^for ([\w0-9]+) in (.*):\s*([^\[\]]*(\[.*)?)/;
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
		} else {
			push(@output, "\n");
		}
	}
	#print ($line, "\n");
	#print(@output);

	return;
}

@scalarVars = ("sys.stdin");
@listVars = ("sys.argv");
@dictVars = ();
@output = ();
@stack = ();		# a record of the levels of indentation on the stack
@knownFuncts = ("print", "range", "len", "int", "sorted", "sys.stdout.write", "sys.stdin.readline","sys.stdin.readlines");

if (defined $ARGV[0]){
	open($FILE, '<', $ARGV[0]);
} else {
	$FILE = STDIN;
}

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
