/*-*- mode:unix-assembly; indent-tabs-mode:t; tab-width:8; coding:utf-8     -*-│
│vi: set et ft=asm ts=8 tw=8 fenc=utf-8                                     :vi│
╞══════════════════════════════════════════════════════════════════════════════╡
│ Copyright 2020 Justine Alexandra Roberts Tunney                              │
│                                                                              │
│ Permission to use, copy, modify, and/or distribute this software for         │
│ any purpose with or without fee is hereby granted, provided that the         │
│ above copyright notice and this permission notice appear in all copies.      │
│                                                                              │
│ THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL                │
│ WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED                │
│ WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE             │
│ AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL         │
│ DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR        │
│ PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER               │
│ TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR             │
│ PERFORMANCE OF THIS SOFTWARE.                                                │
╚─────────────────────────────────────────────────────────────────────────────*/
#include "libc/dce.h"
#include "libc/macros.h"

/	Forks process without copying page tables.
/
/	This is the same as fork() except it's optimized for the case
/	where the caller invokes execve() immediately afterwards. You
/	can also call functions like close(), dup2(), etc. You cannot
/	call read() safely but you can call pread(). Call _exit() but
/	don't call exit(). Look for the vforksafe function annotation
/
/	@return	pid of child process or 0 if forked process
/	@returnstwice
/	@vforksafe
vfork:
#if SupportsWindows()
	testb	IsWindows()
	jnz	fork$nt
#endif
	mov	__NR_vfork(%rip),%eax
	pop	%rsi			# saves return address in a register
#if SupportsBsd()
	testb	IsBsd()
	jnz	vfork.bsd
#endif
	syscall
	push	%rsi			# note it happens twice in same page
	cmp	$-4095,%eax
	jae	systemfive.error
0:	ezlea	__vforked,di
	test	%eax,%eax
	jz	1f
	decl	(%rdi)
	jns	2f			# openbsd doesn't actually share mem
1:	incl	(%rdi)
2:	ret
	.endfn	vfork,globl

#if SupportsBsd()
vfork.bsd:
	syscall
	push	%rsi
	jc	systemfive.errno
#if SupportsXnu()
	testb	IsXnu()
	jz	0b
	neg	%edx			# edx is 0 for parent and 1 for child
	not	%edx			# eax always returned with childs pid
	and	%edx,%eax
#endif /* XNU */
	jmp	0b
	.endfn	vfork.bsd
#endif /* BSD */
