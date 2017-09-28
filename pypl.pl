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

sub replaceScalarsInLine{
	my $line = $_[0];
	if (!defined $line){
		return $line;
	}

	#print ("At line $line, vars are ", join(", ", @variables), "\n");
	foreach my $var (@variables){
		#if ($line =~ /$var/){print("found $var in $line\n");}

		$line =~ s/(^|[^\$])$var/\$$var/g;
	}
	return $line;
}

sub checkAssignment{
	my $ass = $_[0];
	$ass =~ s/ ?(\w+) ?\/\/ ?(\w+) ?/ int\($1\/$2\) /;	#replace python 'x//y' with 'int(x/y)'
	return $ass;
}

sub evaluateExpression{
	my $expr = $_[0];
	#print("Evaluating Expression '$expr'". "\n");
	if (!defined $expr){
		#print("Returning Undef Expression '$expr'". "\n");
		return $expr;
	}
	if ($expr =~ /[\"\+\-\*\/\%]/){
		$expr =~ /([\"\+\-\*\/\%]{1,2})/;
		my $type = $1;
		if ($type =~ /\"/){
			#print("Found String '$expr'". "\n");
			return $expr;
		} elsif ($type =~ /[\+\-\*\/\%]/){
			my $splitter = join("", "\\", join("\\", split(//,$type)));
			#print ("Split Epression '$expr' by '$splitter\n");
			my @lexicon = split(/$splitter/, "$expr", 2);
			if (!defined $lexicon[1]){
				#print("Found Expression '$lexicon[0]'$type in '$expr'". "\n");
				return replaceScalarsInLine($lexicon[0]);
			}
			#print("Found Expression '$lexicon[0]'$type'$lexicon[1]' in '$expr'". "\n");
			return join("", replaceScalarsInLine($lexicon[0]),$type,evaluateExpression($lexicon[1]));
		} else {
			#print("Found Unknown Expr $expr". "\n");
			return replaceScalarsInLine($expr);
		}
	} else {
		#print("Found Terminating Expr $expr". "\n");
		return replaceScalarsInLine($expr);
	}
}

sub evaluateCondition{
	my $condition = $_[0];
	return $condition;
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
	print($line, "\n");

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

	if ($line =~ /^#/){
		#comment
		return;
	} elsif ($line =~ /^print/){
		#print statement
		$line =~ /print\(([^\)]*)\)/;
		my $expr = evaluateExpression($1);
		push(@output, $indent,"print($expr, \"\\n\");\n");
	} elsif ($line =~ /^(\w+)[ ]*=[ ]*(.*)$/){
		#assignment
		#$type = determineVariableType($2);
		push(@variables, $1);
		my $ass = evaluateExpression($2);
		$ass = checkAssignment($ass);
		push(@output, $indent,"\$$1 = $ass;\n");
	} elsif ($line =~ /^(if|while)/) {
		$line =~ /(if|while)\s*([^:]*):\s*(.*)/;
		print("Obtained from $1: condition '$2', and appendage '$3'\n");
		my $condition = evaluateCondition($2);
		push(@output, $indent,"$1($condition){\n");
		my $statements = $3;
		if (defined $statements and $statements =~ /[^\s]/){
			print("Moving '$statements' to new line\n");
			evaluateLine(join("", $indent, "   ", $statements));
		}
	} else {
		#untranslatable, push line as a comment
		if ($line =~ /[^\s]/){
			push(@output, $indent,"#$line\n");
		}
	}
	#print ($line, "\n");
	return;
}

@variables = ();
@output = ();
@stack = ();		# a record of the levels of indentation on the stack

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
