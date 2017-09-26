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

	#print ("At line $line, vars are ", join(", ", @variables), "\n");
	foreach my $var (@variables){
		#if ($line =~ /$var/){print("found $var in $line\n");}
		$line =~ s/$var/\$$var/g;
	}
	return $line;
}

sub checkAssignment{
	$ass = $_[0];
	$ass =~ s/ ?(\w+) ?\/\/ ?(\w+) ?/ int\($1\/$2\) /g;	#replace python 'x//y' with 'int(x/y)'
	return $ass;
}

sub translateStack{
	my @lines = @_;
	foreach my $line (@lines){
		$line = replaceScalarsInLine($line);
		if ($line =~ /^#/){
			next;
		}
		elsif ($line =~ /^print/){
			$line =~ /print\(([^\)]*)\)/;
			push(@output, "print($1, \"\\n\");\n");
		}
		elsif ($line =~ /^(\w+)[ ]*=[ ]*(.*)$/){
			#print("found var $1\n");
			#$type = determineVariableType($2);
			push(@variables, $1);
			my $ass = checkAssignment($2);
			push(@output, "\$$1 = $ass;\n");
		}
		else {
			if ($line =~ /[^\s]/){
				push(@output, "#$line\n");
			}
		}
	}
}


@variables = ();
@output = ();
@lines = (); 							 #all lines
$currentFrame{"frame"} = \@lines; #the current frame in the stack we are adding to
$currentFrame{"indent"} = undef;
#push(@stack, %currentFrame);

open($FILE, '<', $ARGV[0]);

while ($line = <$FILE>){
	$line =~ s/\n//;
	$indent = getLineWhiteSpaces($line);
	if (!defined $currentFrame{"indent"}){
		$currentFrame{"indent"} = $indent;
	}
	$line =~ s/^[ \t]*//;

	#print("Indent $indent for line '$line'\n");
	push(@{$currentFrame{"frame"}}, $line);
}

push(@output, "#!/usr/bin/perl -w\n\n");
translateStack(@lines);

print(@output);
