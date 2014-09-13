#include <stdint.h>

#define MFC0(reg, sel) \
	({ uint32_t res; \
		if (sel == 0) \
			asm volatile( \
				"mfc0 %0, $%1\n\t" \
				: "=r" (res) \
				: "i" (reg)); \
		else \
			asm volatile( \
				"mfc0 %0, $%1, %2\n\t" \
				: "=r" (res) \
				: "i" (reg), "i" (sel)); \
		res; \
	})
#define MTC0(reg, sel, value) \
	do { \
		if (sel == 0) \
			asm volatile( \
				"mtc0 %z0, $%1\n\t" \
				: \
				: "Jr" ((unsigned int)(value)), "i" (reg)); \
		else \
			asm volatile( \
				"mtc0 %z0, $%1, %2\n\t" \
				: \
				: "Jr" ((unsigned int)(value)), "i" (reg), "i" (sel)); \
	} while (0)

#define MTC0_CONFIG(value)   MTC0(16, 0, value)
#define CFG_UNCACHED  2
#define CFG_CACHEABLE 3
#define MTC0_CAUSE(value)    MTC0(13, 0, value)
#define MFC0_STATUS()        MFC0(12, 0)
#define MTC0_STATUS(value)   MTC0(12, 0, value)
#define ST0_CU0       0x10000000
#define ST0_IE        0x00000001
#define ST0_EXL       0x00000002
#define ST0_ERL       0x00000004
#define ST0_KSU       0x00000018
#define MFC0_CONFIGPR()      MFC0(16, 7)
#define MTC0_CONFIGPR(value) MTC0(16, 7, value)
#define CPR_TLB       (1 << 19)
#define CPR_MAP       (1 << 20)
#define CPR_T1        (1 << 3)
#define CPR_T2        (1 << 4)
#define CPR_T3        (1 << 5)
#define CPR_VALID     0x3F1F41FF    /* valid bits to write to ConfigPR */

int main(void) __attribute__((section(".main")));
int main(void) __attribute__((noreturn));

void _init(void) __attribute__((section(".init")));
void _init(void) {
	// enable CP0 and disable all interrupts. zero the rest of the
	// register as well to get well-defined defaults.
	MTC0_STATUS(ST0_CU0);
	// clear all interrupt flags
	MTC0_CAUSE(0);
	
	// disable cache. it should be disabled by default, but make sure it
	// really is. if we initialize it while it's enabled, we risk massive
	// cache corruption.
	MTC0_CONFIG(CFG_UNCACHED);
	
	// disable TLB and static mapping, and stop the timers
	uint32_t configPR = MFC0_CONFIGPR();
	configPR &= CPR_VALID;
	configPR &= ~(CPR_TLB | CPR_MAP);
	configPR |= CPR_T1 | CPR_T2 | CPR_T3;
	MTC0_CONFIGPR(configPR);

	// TODO initialize cache and enable caching
	asm volatile("nop"::);
	
	main();
}