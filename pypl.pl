#!/usr/bin/perl -w

#AUTHOR: James Dowers
#2041 Assignment 1, Convering Python to Perl
#Hosted at: https://github.com/jdowers20/2041-ass1

sub getLineWhiteSpaces{
	#Function to take a line and determine the amount of whitespace in accrodance to PYTHON INDETATION PARSING
	#Input: A line as a string
	#Output: The count of whitespace at the start of the string in number of spaces " "
	
	my $line  = $_[0];
	my $whiteSpace = 0;
	while ($line =~ /^[ \t]/){
		if ($line =~ /^ /){
			$line =~ s/ //;
			$whiteSpace++;
		} else {
			#Repalce tabs with spaces until there is a mutliple of 8 spaces
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
	#Function to take a string and determine if it is the name of a function
	#Input: A string
	#Output: 1 if the string is the name of a known function, 0 otherwise

	my $name = $_[0];
	$name =~ s/\s//;
	

	#Search the known functions list
	foreach my $func (@knownFuncts){
		if ($name eq $func){
			return 1;
		}
	}

	#Test if it is an "x.function" for a variable or string
	if ($name =~ /(.*?)\.(append|pop)/ and varExists($1) eq "\@"){
		return 1;
	}
	if ($name =~ /(.*?)\.(keys)/ and varExists($1) eq "\%"){
		return 1;
	}
	if ($name =~ /(.*?)\.(join|split|group)/){
		return 1;
	}
	return 0;
}

sub determineVariableType{
	#Function to take a variable and determine its type, and add it to the lists if it is new
	#Input: The name of a variable, a necessary variable assignment, and whether or not to push the variable to the lists
	#Output: The symbol ($|@|%) of the corresponding variable type. Note, it is assumed all input will a varaible
	my $name = $_[0];
	my $ass = $_[1];
	my $addToLists = $_[2];

	#If it is an indexed list/dict, variable is a scalar
	if ($name =~ /.*?\[.*?\]/){
		if ($addToLists == 1){
			push(@scalarVars, $name);
		}
		return "\$";
	}

	#Sort and split return lists
	if ($ass =~ /^(sort|split)/){
		if ($addToLists == 1){
			push(@listVars, $name);
		}
		return "\@";
	}

	#Test if it is a known variable, or if the assignment can indicate the type
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
	#Function to take a word and determine if a varaible of that name exists
	#Input: Any string
	#Output: The symbol ($|@|%) of the corresponding variable type, or 0 if it is not a variable

	#Remove indexing
	my $name = $_[0];
	$name =~ s/\[.*?\]//;
	$name =~ s/\{.*?\}//;
	
	#Test each of the variable lists to see if they contain the string
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
	#Function which can be called for any variable name to call the appropriate transformation function
	#See other transformation functions

	my $var = $_[0];
	my $type = determineVariableType($var, "", 0);

	if ($type eq "\%"){
		#No dict transformations, just return %dict
		return "\%$var";
	} elsif ($type eq "\@"){
		return transformList($var);
	} else {
		return transformScalar($var);
	}
}

sub transformList{
	#Function to take a list varaible name and convert it as needed
	#Input: The name of a LIST variable
	#Output: The converted name and symbol for the list variable

	my $var = $_[0];
	if ($var =~ /sys.argv/){
		#Sys.argv: replace with ARGV
		$var = "ARGV";
	}

	#Return the list name with the @
	return "\@$var";
}

sub transformScalar{
	#Function to take a scalar varaible name and convert it as needed
	#Input: The name of a SCALAR variable
	#Output: The converted name and symbol for the scalar variable

	#Determine the variable type
	my $var = $_[0];
	if ($var eq "sys.stdin"){
		#Sys.stdin: Replace with <STDIN>
		return "<STDIN>";

	} elsif($var =~ /(.*?)\[(.*?)\]/) {
		#Indexed List or dict varaible: Return indexed varaible with correct {} or []
		my $name = $1;
		my $par = evaluateExpressionLR($2);
		if (determineVariableType($name, "", 0) eq "\%"){
			#Indexed dict varaible
			return "\$$name\{$par\}";
		} else{
			#Indexed list variable
			if ($name eq "sys.argv"){
				#If sys.argv, reduce all indicies by 1
				$name = "ARGV";
				$par = "$par -1";
				if ($par =~ /:/){
					$par =~ s/:/ -1:/;
				}
			}

			#If there is a ':' in the index, get @list((x..y)) in a temporary variable and return that list
			if ($par =~ /(.*?):(.*)/){
				my $first = $1;
				my $second = $2;
				#If either the first or second value is blank, replace it accrodingly
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
		#If the sacalar variable is none of the above special types, just return $name
		return "\$$var";
	}
}

sub transformFunctions{
	#This function takes in a python function, and converts it into a perl function
	#Input: A python function WITH its EVALUATED parameters
	#Output: A perl function WITH any necessary parameters

	#Determine the type of function
	my $func = $_[0];
	if ($func =~ /^print/){
		#Print Function: return print with corresponding end value included
		if ($func =~ /^print\s*\(\s*\)/){
			#If there are no parameters, print a newline
			return "print(\"\\n\")";
		}

		#Set the default end to be a newline, and if an end keyword argument is found, reset the end value
		my $end = "\"\\n\"";
		if ($func =~ /,\s*end\s*=\s*(.*?)\)/){
			$func =~ s/,\s*end\s*=\s*(.*?)\)//;
			$end = evaluateExpressionLR($1);
		}

		#Return the print function with the correct end value appended
		$func =~ s/\)\s*$//;
		$func = join("", $func, ", $end)");
		return $func;

	} elsif($func =~ /^range/) {
		#Range function: Replace with (x..y-1), note that the perl range is inclusive of its upper bound
		$func =~ /range\((.*)/;
		my $pars =  $1;
		$pars =~ s/\)\s*$//;
		my @args = split(/,/, $pars, 2);

		if (defined $args[1]){
			#if two parameters were specified, print (x..y-1)
			my $upper = join("",$args[1],"-1");
			return "($args[0]..$upper)";
		} else {
			#if only one parameter was specified, print (0..x-1)
			my $upper = join("",$args[0],"-1");
			return "(0..$upper)";
		}

	} elsif($func =~ /^open\((.*)/) {
		#Open Function: Open file for input, only one argument handled
		my $par = $1;
		$par =~ s/\)\s*$//;
		$par =~ s/["']//g;

		#Print the function call in the line preceding the function, and replace the function with <F>
		push(@output, $indent, "open F, \"<$par\" or die \"\$: can not open file: \$!\";\n");
		return "<F>";

	} elsif($func =~ /^sys\.stdout\.write/) {
		#Sys.stdout.write: Simply replace with print
		$func =~ s/sys\.stdout\.write/print/;
		return $func;

	} elsif($func =~ /^fileinput\.input/) {
		#fileinput.input: Replace with <>
		return "<>";

	} elsif($func =~ /^sorted\s*\((.*)/) {
		#Sorted function: Replace with sort function
		my $par = $1;
		$par =~ s/\)\s*$//;
		$par = evaluateExpressionLR($par);
		return "sort($par)";

	} elsif($func =~ /^sys\.stdin\.readline\(/) {
		#Sys.stdin.readline: Replace with <STDIN>
		$func =~ s/sys\.stdin\.readline\(.*?\)/<STDIN>/;
		return $func;

	} elsif($func =~ /^sys\.stdin\.readlines/) {
		#sys.stdin.readlines: Print a while loop to read stdin into a list, immadeiately peceeding the function line
		#Then replace the function call with the temporary list with all the lines in it
		push(@output, "$indent","while(\$tmpLineReader = <STDIN>){\n");
		push(@output, "$indent","   chomp(\$tmpLineReader);\n");
		push(@output, "$indent","   push(\@tmpLines, \$tmpLineReader);\n");
		push(@output, "$indent","}\n");
		$func = "\@tmpLines";
		return $func;

	} elsif($func =~ /(.*?)\.append\((.*)/){
		#.append: replace with a push function to the list
		my $list = $1;
		my $app = $2;
		$app =~s/\)\s*$//;
		$app = evaluateExpressionLR($app);
		return "push(\@$list, $app)";

	} elsif($func =~ /(.*?)\.keys\(\)/){
		#.keys Function: replace with perl keys() function 
		my $dict = $1;
		return "keys($dict)";

	} elsif($func =~ /(.*?)\.pop\((.*?)\)/){
		#.pop: replace with splice function on the list, at the index given in the parameter
		my $list = $1;
		my $index = $2;
		if ($index eq ""){
			#If there is no parameter, splice the last element
			$index = "-1";
		} else {
			$index = evaluateExpressionLR($index);
		}
		return "splice(\@$list, $index)"

	} elsif($func =~ /len\((.*)/){
		#len Function: If the paramter is a list, replace with scalar @list
		#Otherwise replace with perl length function
		my $par = $1;
		$par =~ s/\)\s*$//;
		$par = evaluateExpressionLR($par);
		if ($par =~ /\@(.*)?/){
			if ($1 eq "ARGV"){
				#If the list is ARGV, increase the value by one, as python includes the file name
				$par = "$par +1";
			}
			return "scalar $par";
		} else {
			return "length($par)";
		}

	} elsif($func =~ /re\.match\(["'](.*)["']\s*,\s*(.*?)\s*\)/){
		#re.match: Replace with a regex search at the START of the variable
		my $str = $1;
		my $var = $2;
		return "$var =~ /^$str/";

	} elsif($func =~ /re\.search\(["'](.*)["']\s*,\s*(.*?)\s*\)/){
		#re.search: Replace with a regex search over the variable
		my $str = $1;
		my $var = $2;
		return "$var =~ /$str/";

	} elsif($func =~ /re\.sub\(["'](.*)["']\s*,\s*["'](.*)["']\s*,\s*(.*?)\s*\)/){
		#re.sub: First print the s/// over a variable, then let replace the function with the variable we changed
		my $str = $1;
		my $rep = $2;
		my $var = $3;
		push(@output, $indent, "$var =~ s/$str/$rep/g;\n");
		return "$var";

	} elsif($func =~ /(.*?)\.split\((.*?)/){
		#.split: replace with perl split
		my $prefix = $1;
		my $par = $2;
		$par =~ s/\)\s*$//;
		if ($par =~ /["'](.*?)["']/){
			return join("", "split(/$1/, ",evaluateExpressionLR($prefix),")");
		} else{
			#If no parameter was give, use default ' ' paramter
			return join("", "split(/ /, ",evaluateExpressionLR($prefix),")");
		}

	} elsif($func =~ /(.*?)\.join\((.*)/){
		#.join Function: Replace with perl join function
		my $prefix = $1;
		my $par = $2;
		$par =~ s/\)\s*$//;
		return join("", "join($prefix, ",evaluateExpressionLR($par),")");

	} elsif($func =~ /.*?\.group\(\s*(.*)/){
		#Regex .group function: Replace with $x where x is the specified capture group
		my $par = $1;
		$par =~ s/\s*\)\s*$//;
		return join("", "\$", $par);

	}
	return $func;
}

sub retrieveFunction{
	#This function takes an expression and returns the leftmost function, with its parameters
	#Input: An expression that strictly contains a function as its leftmost part
	#Output: A list with the function and parameters at the first index, succeeded by the remaining characters in the expression

	#Split the expression up into the function name, any white space, and all other characters
	my $input = $_[0];
	$input =~ /^((["'].*?["'])?[\w0-9\.]+)(\s*)\((.*)/;
	my $func = $1;
	my $space = $3;
	my $rem = $4;
	my @chars = split(//, $rem);

	#Retrieve the parameters of the function by moving through the expression until the correct close parenthesis is found
	#Start "parenthesis depth" at 1, and move through the expression until the "parenthesis depth" is 0
	my $pars = "(";
	my $depth = 1;
	my $char = shift(@chars);
	while (defined $char){
		if ($char eq "("){
			$depth++;
		}elsif ($char eq ")"){
			$depth--;
		}
		#Append character to the parameters string until the close parenthesis is found
		$pars = join("", $pars, $char);

		if ($depth == 0){
			last;
		}
		$char = shift(@chars);
	}

	#return the joined function name and evaluated parameters, followed by all remaining chars
	return (join("", $func, $space, evaluateExpressionLR($pars)), @chars);
}

sub evaluateExpressionLR{
	#Function which recerusively evaluates python expressions into their perl equivalent
	#Moves left to right across expressions
	#Input: A single python expression
	#Output: The converted perl expression

	#ignore empty expressions
	my $expr = $_[0];
	if (!defined $expr){
		return "";
	}
	if ($expr eq ""){
		return "";
	}

	#Convert different types of expressions differently
	if ($expr =~ /^["']/){
		#String Expression: Extract the string, as well as any potential formatting
		$expr =~ /^("[^"]*"|'[^']*')(\s*%\s*\(.*?\))?(.*)/;
		my $str = $1;
		my $format = $2;
		my $rem = $3;

		if (defined $format and $format ne ""){
			#If formatting was extraced, return a sprintf
			$format =~ s/\s*%\s*\(/\(/;
			$format = evaluateExpressionLR($format);
			return join("", "sprintf($str, $format)", $rem)
		} else {
			#If no formatting was extracted, check for a .split or .join
			if($rem =~ /\.(split|join)/){
				#Return a join or split function
				my @pack = retrieveFunction($expr);
				my $funct = transformFunctions(shift(@pack));
				return join("", "$funct",evaluateExpressionLR(join("",@pack)));
			}
			#Return a plain string
			return join("", $str, evaluateExpressionLR($rem));
		}

	} elsif ($expr =~ /^r["']/){
		#Raw string expression, remove the r and evaluate the string
		$expr =~ /^r("[^"]*"|'[^']*')(.*)/;
		my $str = $1;
		my $rem = evaluateExpressionLR($2);
		return join("", $str, $rem);

	} elsif	($expr =~ /^(\(|\))/){
		#Bracket: Print brackets as they appear, and evaluate the rest of the expression
		$expr =~ /^(\(|\))(.*)/;
		my $bracket = $1;
		return join("", $bracket, evaluateExpressionLR($2));
		
	} elsif	($expr =~ /^[0-9\w]/){
		#Word/Number/Variable/Number Expression: First determine type
		$expr =~ /^([0-9\w\.]+(\[.*?\])*)+/;
		my $word = $1;
		#When using regex, some symbols may need to be escaped
		my $escWord = $word;
		$escWord =~ s/([\.\[\]])/\\$1/g;

		#determine expression type
		if (varExists($word)){
			#Variable: Transform the variable into its perl equivalent
			$expr =~ /^$escWord(.*)/;
			my $rem = $1;
			$word = transformVar($word);

			return join("", "$word",evaluateExpressionLR($rem));

		} elsif(isFunct($word) == 1){
			#Function: Get the Function and its arguments and convert them
			#Note, when retrieving a function from an expression, a packet is returned
			#where the function is the first index, and the rest of the expression is in the remaineing indicies
			my @pack = retrieveFunction($expr);
			my $funct = transformFunctions(shift(@pack));

			return join("", "$funct",evaluateExpressionLR(join("",@pack)));

		} elsif ($word eq "and" or $word eq "or" or $word eq "and" ){
			#Comparator Word: These are equivalent in python and perl
			$expr =~ /^$escWord(.*)/;
			return join("", $word, evaluateExpressionLR($1));

		} else {
			#Push line as a comment
			$expr =~ /^$escWord(.*)/;
			return join("", "$word", evaluateExpressionLR($1));
		}

	} elsif	($expr =~ /^(<=|<|>=|>|!=|==)/){
		#Comparator Expression: Equivalent between perl and python
		my $comp = $1;
		$expr =~ /^$comp(.*)/;
		return join("", $comp, evaluateExpressionLR($1));

	} elsif	($expr =~ /^([\+\-\*\/\%]{1,2})/){
		#Mathematical Operator Expression: Equivalent between perl and python, but all need to be escaped
		my $oper = $1;
		my $escoper = join("", "\\", split(//, $oper));
		$expr =~ /^$escoper(.*)/;
		if ($oper eq "//"){$oper = "/";}
		return join("", $oper, evaluateExpressionLR($1));

	} elsif	($expr =~ /^(<<|>>|&|~)/){
		#Bitwise Expression: Equivalent between perl and python, except for ~
		my $bitw = $1;
		if ($bitw eq "~"){
			#If operator is ~x, replace with -x-1
			$expr =~ /^~([0-9\w\.\[\]]+)(.*)/;
			my $var = $1;
			my $rem = $2;

			return join("", "-",evaluateExpressionLR($var),"-1",evaluateExpressionLR($rem));
		}
		$expr =~ /^$bitw(.*)/;

		return join("", $bitw, evaluateExpressionLR($1));

	} elsif	($expr =~  /(\^|\|)/){
		#Escaped Bitiwise Operators: The | and ^ are identical between perl and python
		#but need to be escaped in the regex search
		my $Bitw = $1;
		my $escBitw = join("", "\\", $Bitw);
		$expr =~ /^$escBitw(.*)/;

		return join("", $Bitw, evaluateExpressionLR($1));

	} elsif	($expr =~ /^,/){
		#Comma: Commas are kept in place
		$expr =~ /^,(.*)/;

		return join("", ",", evaluateExpressionLR($1));

	} elsif	($expr =~ /^[\[\]]/){
		#Brackets: These are replaced with parentheses.
		#This is only for intialising variables, as brackets for array indexes are caught above as a variable
		$expr =~ /^([\[\]])(.*)/;
		my $bracket = $1;
		my $rem = $2;
		$bracket =~ s/\[/\(/;
		$bracket =~ s/\]/\)/;

		return join("", $bracket, evaluateExpressionLR($rem));

	} elsif	($expr =~ /^\s/){
		#whitespace: Collect whitespace and print it
		#Whitespace will generally be collected with other expressions
		$expr =~ /^(\s+)(.*)/;
		my $space = $1;

		return join("", $space, evaluateExpressionLR($2));

	} else {
		#If the expressions does not match any known types, return it as is
		return $expr;
	}
	
}

sub generateWhiteSpace{
	#This sub gets takes an integer as input and returns that many spaces as a single string
	#Used to convert all whitespace into spaces
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
	#This function takes in a line, translates it, and pushes it to output
	#Expected input: Exactly one line
	#Exepcted output: None

	#Trim the line and get the whitespace
	my $line = $_[0];
	my $indentLength = getLineWhiteSpaces($line);
	$indent = generateWhiteSpace($indentLength);
	$line =~ s/^[\s]*//;
	$line =~ s/\n//;

	#If the line is a comment (exluding the #!), push it and ignore the indentation
	if ($line =~ /^#/){
		#comment
		if ($line =~ /^#[^!]/){
			push (@output, "$line\n");
			return;
		}
		return;	
	}

	#determine if stack needs to be added to, or closed by comparing the indenation of the current line
	my $top = pop(@stack);
	while($top != $indentLength){
		if($top < $indentLength){
			push(@stack, $top);
			$top = $indentLength;
		} elsif ($top > $indentLength){
			$top = pop(@stack);
			push(@output, join("", generateWhiteSpace($top), "}\n"));
		}
	}
	push(@stack, $top);

	#split line if needed, and evaluate each part
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

	#At this point, determine what type of line is being handled
	if ($line =~ /^import/){
		#ignore import lines
		return;

	} elsif ($line =~ /^([\w0-9\.\[\]]+)[ ]*=[ ]*(.*)$/){
		#assignment line: get the variable, its type and its evaluated assignment
		my $var = $1; 
		my $ass = evaluateExpressionLR($2);
		my $type = determineVariableType($var, $ass, 1);
		if ($ass eq "\{\}"){return;}

		push(@output, $indent,"$type$var = $ass;\n");

	} elsif ($line =~ /^(if|while|elif)/) {
		#Conditional Line: get the keyword and evaluate condition and any additional statments
		$line =~ /(if|while|elif)\s*([^:]*):\s*(.*)/;
		my $type = $1;
		if ($type eq "elif"){$type = "elsif"}
		my $condition = evaluateExpressionLR($2);
		my $statements = $3;

		push(@output, $indent,"$type($condition){\n");
		if (defined $statements and $statements =~ /[^\s]/){
			#if there are any extra statements on this single line, evaluate them separately on new lines
			evaluateLine(join("", $indent, "   ", $statements));
		}

	} elsif ($line =~ /^else/) {
		#else statements: this is simpple as the indentation and } are handled separately
		push(@output, $indent,"else {\n");

	} elsif ($line =~ /^for/) {
		#for line: convert to a foreach and evaluate condition and any additional statments
		$line =~ /^for ([\w0-9]+) in (.*):\s*([^\[\]]*(\[.*)?)/;
		my $var = $1;
		my $set = $2;
		my $statements = $3;
		push(@scalarVars, $var);
		$set = evaluateExpressionLR($set);

		push(@output, $indent,"foreach \$$var ($set){\n");
		if (defined $statements and $statements =~ /[^\s]/){
			#if there are any extra statements on this single line, evaluate them separately on new lines
			evaluateLine(join("", $indent, "   ", $statements));
		}

	} elsif ($line =~ /^continue/) {
		#continue: replace with next
		push(@output, $indent,"next;\n");

	} elsif ($line =~ /^break/) {
		#break: replace with last
		push(@output, $indent,"last;\n");

	} elsif ($line =~ /^def (.*?)\s*\((.*?)\)\s*:/) {
		#function definition line: get the name and push the parameters onto newlines
		my $name = $1;
		my $pars = $2;
		push(@knownFuncts, $name);

		push(@output, $indent,"sub $name\{\n");

		#for the parameters, push each onto a newline and get their values from the perl $_[x] value
		# eg def a(b,c): ... would look something like a{b=$_[0]; c=$_[1]; ... }
		my @parList = split(/,/, $pars);
		my $count = 0;
		foreach my $par (@parList){
			$par =~ s/\s//g;
			push(@output,$indent, "\t\$$par = \$_\[$count\];\n");
			$count++;
			push(@scalarVars, $par)
		}

	} elsif ($line =~ /^return\s*(.*)/) {
		#return: get the return values and evaluate them in perl
		my $ret = $1;
		$ret = evaluateExpressionLR($ret);

		push(@output, $indent,"return $ret;\n");

	} else {
		#if the line is none of these, assume it is just an expression or a function call
		#if the line is just whitespace, push a newline
		$line = evaluateExpressionLR($line);
		if ($line =~ /[^\s]/){
			push(@output, $indent,"$line;\n");
		} else {
			push(@output, "\n");
		}
	}

	return;
}

#----------------MAIN--------------------------------

#some global variables
@scalarVars = ("sys.stdin");	#scalar variables
@listVars = ("sys.argv");		#list variables
@dictVars = ();					#dict variables
@output = ();					#cumulative perl output code
@stack = ();					#the levels of indentation on the stack
@knownFuncts = ("print", "range", "len", "int", "sorted", "open", "fileinput.input", "sys.stdout.write", "sys.stdin.readline","sys.stdin.readlines", "re.match", "re.sub", "re.search");
#^list of all known functions

#open a file from the first argument or open STDIN
if (defined $ARGV[0]){
	open($FILE, '<', $ARGV[0]);
} else {
	$FILE = STDIN;
}

push(@output, "#!/usr/bin/perl -w\n\n");

#read each line and convert the pyton code to perl code
$first = 1;
while ($line = <$FILE>){
	if ($first == 1){
		#This ensures that we push the indetation of the first line onto the stack
		push(@stack, getLineWhiteSpaces($line));
		$first = 0;
	}
	evaluateLine($line);
}
#ensure that there is always a newline at the EOF
evaluateLine("\n");

#print the entire perl translated code
print(@output);
