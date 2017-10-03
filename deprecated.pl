

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

sub checkAssignment{
	my $ass = $_[0];
	$ass =~ s/ ?(\w+) ?\/\/ ?(\w+) ?/ int\($1\/$2\) /;	#replace python 'x//y' with 'int(x/y)'
	return $ass;
}

sub replaceScalarsInLine{
	my $line = $_[0];
	if (!defined $line){
		return $line;
	}

	#print ("At line $line, vars are ", join(", ", @variables), "\n");
	foreach my $var (@variables){
		#if ($line =~ /$var/){print("found $var in $line\n");}

		$line =~ s/(^|[^\$])$var/$1\$$var/g;
	}
	return $line;
}


sub evaluateExpression{
	my $expr = $_[0];
	#print("Evaluating Expression '$expr'". "\n");
	if (!defined $expr){
		return "";
	}
	if ($expr eq ""){
		return "";
	}
	#print("Found Expression'$expr'\n");

	if ($expr =~ /(\w\.+)\s*\((.*?)\)/ and isFunct($1)){
		print("function\n");
		#$expr =~ /(\w\.+)\s*\((.*?)\)/;
		#my $funct = $1;
		#my $args = $2;
		#print("Found '$funct($args)'\n");
		#$expr =~ /(.*?)$funct\s*\(.*?\)(.*)/;
		#return join("", evaluateCondition($1),$funct,"(",$args,")",evaluateCondition($2));
	} elsif ($expr =~ /([\+\-\*\/\%]{1,2})/){
		my $type = $1;
		#print("Found num '$expr'". "\n");
		my $splitter = join("", "\\", join("\\", split(//,$type)));
		my @lexicon = split(/$splitter/, "$expr", 2);
		if (!defined $lexicon[1]){
			return evaluateCondition($lexicon[0]);
		}
		return join("", evaluateCondition($lexicon[0]),$type,evaluateCondition($lexicon[1]));
	} elsif ($expr =~ /(<<|>>|&|~)/){
		my $type = $1;
		#print("Condition Type '$type'\n");
		$expr =~ /(.*?)$type(.*)/;
		return join("", evaluateCondition($1),$type,evaluateCondition($2));
	} elsif ($expr =~ /(\^|\|)/){
		my $type = $1;
		#print("Condition Type '$type'\n");
		my $splitter = join("", "\\", $type);
		#print("Evaluating regex '/(.*?)\$type(.*)/'\n");
		$expr =~ /(.*?)$splitter(.*)/;
		return join("", evaluateCondition($1),$type,evaluateCondition($2));
	} else {
		#print("Found Terminating Expr $expr". "\n");
		return replaceScalarsInLine($expr);
	}
}

sub evaluateCondition{
	my $condition = $_[0];
	if (!defined $condition){
		return "";
	}
	if ($condition eq ""){
		return "";
	}
	print("Evaluating Condition '",$condition,"'\n");

	if ($condition =~ /[^\w](and|or|not)[^\w]/){
		my $type = $1;
		#print("Condition Type '$type'\n");
		$condition =~ /(.*?)$type(.*)/;
		return join("", evaluateCondition($1),$type, evaluateCondition($2));
	} elsif ($condition =~ /(<|<=|>|>=|!=|==)/){
		my $type = $1;
		#print("Condition Type '$type'\n");
		$condition =~ /(.*?)$type(.*)/;
		return join("", evaluateCondition($1),$type, evaluateCondition($2));
	} else {
		#print("Condition is Expression\n");
		return evaluateExpression($condition);		
	}
}