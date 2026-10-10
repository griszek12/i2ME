#ifndef LEGACY_ATOMIC_H
#define LEGACY_ATOMIC_H
#include <pthread.h>
extern pthread_mutex_t legacy_atomic_mutex;
typedef int atomic_int;
#define memory_order_relaxed 0
#define memory_order_acquire 0
#define memory_order_release 0
#define memory_order_acq_rel 0
#define memory_order_seq_cst 0
#define __ATOMIC_RELAXED 0
#define __ATOMIC_SEQ_CST 0
#define atomic_init(p,v) (*(p)=(v))
#define atomic_load_explicit(p,o) ({ pthread_mutex_lock(&legacy_atomic_mutex); __typeof__(*(p)) result=*(p); pthread_mutex_unlock(&legacy_atomic_mutex); result; })
#define atomic_load(p) atomic_load_explicit(p,0)
#define atomic_exchange_explicit(p,v,o) ({ pthread_mutex_lock(&legacy_atomic_mutex); __typeof__(*(p)) result=*(p); *(p)=(v); pthread_mutex_unlock(&legacy_atomic_mutex); result; })
#define atomic_store_explicit(p,v,o) ((void)atomic_exchange_explicit(p,v,o))
#define atomic_store(p,v) atomic_store_explicit(p,v,0)
#define atomic_fetch_add_explicit(p,v,o) ({ pthread_mutex_lock(&legacy_atomic_mutex); __typeof__(*(p)) result=*(p); *(p)+=(v); pthread_mutex_unlock(&legacy_atomic_mutex); result; })
#define atomic_fetch_sub_explicit(p,v,o) atomic_fetch_add_explicit(p,-(v),o)
#define atomic_fetch_add(p,v) atomic_fetch_add_explicit(p,v,0)
#define atomic_fetch_sub(p,v) atomic_fetch_sub_explicit(p,v,0)
#define atomic_compare_exchange_weak_explicit(p,e,v,a,b) ({ pthread_mutex_lock(&legacy_atomic_mutex); int success=(*(p)==*(e)); if(success) *(p)=(v); else *(e)=*(p); pthread_mutex_unlock(&legacy_atomic_mutex); success; })
#define atomic_thread_fence(o) __sync_synchronize()
#define __atomic_load_n(p,o) atomic_load_explicit(p,o)
#define __atomic_store_n(p,v,o) atomic_store_explicit(p,v,o)
#define __atomic_fetch_add(p,v,o) atomic_fetch_add_explicit(p,v,o)
#define __atomic_fetch_sub(p,v,o) atomic_fetch_sub_explicit(p,v,o)
#define __atomic_exchange_n(p,v,o) atomic_exchange_explicit(p,v,o)
#endif
