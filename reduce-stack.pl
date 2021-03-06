#!/usr/bin/perl -wni

BEGIN {
	$state = 'wilderness';
	$sp = '#';
	$fun = '#';
	@regs = qw<
		$zero $at   $v0   $v1   $a0   $a1   $a2   $a3
		$t0   $t1   $t2   $t3   $t4   $t5   $t6   $t7
		$s0   $s1   $s2   $s3   $s4   $s5   $s6   $s7
		$t8   $t9   $k0   $k1   $gp   $sp   $fp   $ra>;
}

my $orig = $_;
chomp;
s/#.*$//;
s/\s+/ /g;
s/^ //;
s/ $//;

# check: make sure we are inside a function when rewriting .frame
if (/^\.ent ([a-z0-9_]+)/i) {
	die "$./$_ in state $state\n" unless $state eq 'wilderness';
	$fun = $1;
	$state = 'preamble';
} elsif (/^\.end $fun/i) {
	die "$./$_ in state $state\n" unless $state eq 'function';
	$state = 'wilderness';

# rewrite the .frame declaration, removing all registers saved during
# the prologue.

# rewrite the .frame declaration, removing all registers saved during
# the prologue.
} elsif (/^\.frame \$([a-z0-9]+), ?(\d+), ?\$([a-z0-9]+)/i) {
	die "$./$_ in state $state\n" unless $state eq 'preamble';
	$sp = $1;
	$size = int $2;
	$ra = $3;
	$state = 'frame';
	$orig = ""; # remove; will be restored after .mask
} elsif (/^\.mask 0x([a-f0-9]+), ?(.*)/i) {
	die "$./$_ in state $state\n" unless $state eq 'frame';
	my $mask = hex $1;
	my $rest = $2;
	
	%saved = ();
	$regs = 0;
	for ($i = 0; $i < 32; $i++) {
		if ($mask & (1 << $i)) {
			$saved{"\$$i"} = 1;
			$saved{$regs[$i]} = 1;
			$regs++;
		}
	}
	$newsize = $size - 4*$regs;
	print STDERR "$./$fun: reducing frame size $size -> $newsize\n"
			unless $newsize == $size;
	
	$state = 'function';
	print "\t.frame \$$sp,$size,\$$ra\n";
	print "\t.mask 0x00000000,$rest\n";
	$orig = ""; # remove original; we just replaced it

# adjust size of allocated stack frame. not really necessary because we
# have plenty of ram, but this gives a good opportunity to check whether
# there is any other manipulation of the stack pointer. if there is any,
# it'll break the assumption that the top N entries refer to the register
# saving slots and thus make the optimization unsafe. therefore, if any
# unexpected stack pointer modification is detected, we just panic.
} elsif (/^addiu \$$sp, ?\$$sp, ?(-?\d+)/i) {
	die "$./$_ in state $state\n" unless $state eq 'function';
	my $sz = -int $1;
	
	die "$./illegal stack manipulation: $_\n" unless $sz eq $size;
	print "\taddiu \$$sp, \$$sp, -$newsize\n";
	$orig = ""; # remove original; we just replaced it
	print STDERR "$./$fun: reducing allocation $sz -> $newsize\n";

# remove any operations that store a saved register to a stack offset
# used for register saving.
} elsif (/^([ls]w) (\$[0-9a-z]+), ?(\d+)\(\$$sp\)/i) {
	die "$./$_ in state $state\n" unless $state eq 'function';
	my $op = $1;
	my $reg = $2;
	my $off = int $3;
	
	if ($off >= $newsize) {
		die "$./$op $reg to register-saving offset $off\n" unless $saved{$reg};
		delete $saved{$reg};
		print STDERR "$./$fun: removing $op $reg, $off(\$$sp)\n";
		$orig = ""; # zap the instruction
	}
}
print $orig;
