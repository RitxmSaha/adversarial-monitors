" firejail.vim.  Generated from firejail.vim.in by make.
" Vim syntax file
" Language: Firejail security sandbox profile
" URL: https://github.com/netblue30/firejail

if exists("b:current_syntax")
  finish
endif


syn iskeyword @,48-57,_,.,-


syn keyword fjTodo TODO FIXME XXX NOTE contained
syn match fjComment "#.*$" contains=fjTodo

"TODO: highlight "dangerous" capabilities differently, as is done in apparmor.vim?
syn keyword fjCapability audit_control audit_read audit_write block_suspend chown dac_override dac_read_search fowner fsetid ipc_lock ipc_owner kill lease linux_immutable mac_admin mac_override mknod net_admin net_bind_service net_broadcast net_raw setgid setfcap setpcap setuid sys_admin sys_boot sys_chroot sys_module sys_nice sys_pacct sys_ptrace sys_rawio sys_resource sys_time sys_tty_config syslog wake_alarm nextgroup=fjCapabilityList contained
syn match fjCapabilityList /,/ nextgroup=fjCapability contained

syn keyword fjNamespaces cgroup ipc net mnt pid time user uts nextgroup=fjNamespacesList contained
syn match fjNamespacesList /,/ nextgroup=fjNamespaces contained

syn keyword fjProtocol unix inet inet6 netlink packet nextgroup=fjProtocolList contained
syn match fjProtocolList /,/ nextgroup=fjProtocol contained

" Syscalls (auto-generated)
syn keyword fjSyscall _llseek _newselect _sysctl accept accept4 access acct add_key adjtimex afs_syscall alarm arch_prctl arm_fadvise64_64 arm_sync_file_range bdflush bind bpf break brk cachestat capget capset chdir chmod chown chown32 chroot clock_adjtime clock_adjtime64 clock_getres clock_getres_time64 clock_gettime clock_gettime64 clock_nanosleep clock_nanosleep_time64 clock_settime clock_settime64 clone clone3 close close_range connect copy_file_range creat create_module delete_module dup dup2 dup3 epoll_create epoll_create1 epoll_ctl epoll_ctl_old epoll_pwait epoll_pwait2 epoll_wait epoll_wait_old eventfd eventfd2 execve execveat exit exit_group faccessat faccessat2 fadvise64 fadvise64_64 fallocate fanotify_init fanotify_mark fchdir fchmod fchmodat fchmodat2 fchown fchown32 fchownat fcntl fcntl64 fdatasync fgetxattr finit_module flistxattr flock fork fremovexattr fsconfig fsetxattr fsmount fsopen fspick fstat fstat64 fstatat64 fstatfs fstatfs64 fsync ftime ftruncate ftruncate64 futex futex_requeue futex_time64 futex_wait futex_waitv futex_wake futimesat get_kernel_syms get_mempolicy get_robust_list get_thread_area getcpu getcwd getdents getdents64 getegid getegid32 geteuid geteuid32 getgid getgid32 getgroups getgroups32 getitimer getpeername getpgid getpgrp getpid getpmsg getppid getpriority getrandom getresgid getresgid32 getresuid getresuid32 getrlimit getrusage getsid getsockname getsockopt gettid gettimeofday getuid getuid32 getxattr gtty idle init_module inotify_add_watch inotify_init inotify_init1 inotify_rm_watch io_cancel io_destroy io_getevents io_pgetevents io_pgetevents_time64 io_setup io_submit io_uring_enter io_uring_register io_uring_setup ioctl ioperm iopl ioprio_get ioprio_set ipc kcmp kexec_file_load kexec_load keyctl kill landlock_add_rule landlock_create_ruleset landlock_restrict_self lchown lchown32 lgetxattr link linkat listen listmount listxattr llistxattr lock lookup_dcookie lremovexattr lseek lsetxattr lsm_get_self_attr lsm_list_modules lsm_set_self_attr lstat lstat64 madvise map_shadow_stack mbind membarrier memfd_create memfd_secret migrate_pages mincore mkdir mkdirat mknod mknodat mlock mlock2 mlockall mmap mmap2 modify_ldt mount mount_setattr move_mount move_pages mprotect mpx mq_getsetattr mq_notify mq_open mq_timedreceive mq_timedreceive_time64 mq_timedsend mq_timedsend_time64 mq_unlink mremap mseal msgctl msgget msgrcv msgsnd msync munlock munlockall munmap name_to_handle_at nanosleep newfstatat nfsservctl nice oldfstat oldlstat oldolduname oldstat olduname open open_by_handle_at open_tree openat openat2 pause pciconfig_iobase pciconfig_read pciconfig_write perf_event_open personality pidfd_getfd pidfd_open pidfd_send_signal pipe pipe2 pivot_root pkey_alloc pkey_free pkey_mprotect poll ppoll ppoll_time64 prctl pread64 preadv preadv2 prlimit64 process_madvise process_mrelease process_vm_readv process_vm_writev prof profil pselect6 pselect6_time64 ptrace putpmsg pwrite64 pwritev pwritev2 query_module quotactl quotactl_fd read readahead readdir readlink readlinkat readv reboot recv recvfrom recvmmsg recvmmsg_time64 recvmsg remap_file_pages removexattr rename renameat renameat2 request_key restart_syscall rmdir rseq rt_sigaction rt_sigpending rt_sigprocmask rt_sigqueueinfo rt_sigreturn rt_sigsuspend rt_sigtimedwait rt_sigtimedwait_time64 rt_tgsigqueueinfo sched_get_priority_max sched_get_priority_min sched_getaffinity sched_getattr sched_getparam sched_getscheduler sched_rr_get_interval sched_rr_get_interval_time64 sched_setaffinity sched_setattr sched_setparam sched_setscheduler sched_yield seccomp security select semctl semget semop semtimedop semtimedop_time64 send sendfile sendfile64 sendmmsg sendmsg sendto set_mempolicy set_mempolicy_home_node set_robust_list set_thread_area set_tid_address setdomainname setfsgid setfsgid32 setfsuid setfsuid32 setgid setgid32 setgroups setgroups32 sethostname setitimer setns setpgid setpriority setregid setregid32 setresgid setresgid32 setresuid setresuid32 setreuid setreuid32 setrlimit setsid setsockopt settimeofday setuid setuid32 setxattr sgetmask shmat shmctl shmdt shmget shutdown sigaction sigaltstack signal signalfd signalfd4 sigpending sigprocmask sigreturn sigsuspend socket socketcall socketpair splice ssetmask stat stat64 statfs statfs64 statmount statx stime stty swapoff swapon symlink symlinkat sync sync_file_range syncfs sysfs sysinfo syslog tee tgkill time timer_create timer_delete timer_getoverrun timer_gettime timer_gettime64 timer_settime timer_settime64 timerfd_create timerfd_gettime timerfd_gettime64 timerfd_settime timerfd_settime64 times tkill truncate truncate64 tuxcall ugetrlimit ulimit umask umount umount2 uname unlink unlinkat unshare uselib userfaultfd ustat utime utimensat utimensat_time64 utimes vfork vhangup vm86 vm86old vmsplice vserver wait4 waitid waitpid write writev nextgroup=fjSyscallErrno contained
" Syscall groups (auto-generated)
syn match fjSyscall /\v\@(aio|basic-io|chown|clock|cpu-emulation|debug|default|default-keep|default-nodebuggers|file-system|io-event|ipc|keyring|memlock|module|mount|network-io|obsolete|privileged|process|raw-io|reboot|resources|setuid|signal|swap|sync|system-service|timer)>/ nextgroup=fjSyscallErrno contained
syn match fjSyscall /\$[0-9]\+/ nextgroup=fjSyscallErrno contained
" Errnos (auto-generated)
syn match fjSyscallErrno /\v(:(E2BIG|EACCES|EADDRINUSE|EADDRNOTAVAIL|EADV|EAFNOSUPPORT|EAGAIN|EALREADY|EBADE|EBADF|EBADFD|EBADMSG|EBADR|EBADRQC|EBADSLT|EBFONT|EBUSY|ECANCELED|ECHILD|ECHRNG|ECOMM|ECONNABORTED|ECONNREFUSED|ECONNRESET|EDEADLK|EDEADLOCK|EDESTADDRREQ|EDOM|EDOTDOT|EDQUOT|EEXIST|EFAULT|EFBIG|EHOSTDOWN|EHOSTUNREACH|EHWPOISON|EIDRM|EILSEQ|EINPROGRESS|EINTR|EINVAL|EIO|EISCONN|EISDIR|EISNAM|EKEYEXPIRED|EKEYREJECTED|EKEYREVOKED|EL2HLT|EL2NSYNC|EL3HLT|EL3RST|ELIBACC|ELIBBAD|ELIBEXEC|ELIBMAX|ELIBSCN|ELNRNG|ELOOP|EMEDIUMTYPE|EMFILE|EMLINK|EMSGSIZE|EMULTIHOP|ENAMETOOLONG|ENAVAIL|ENETDOWN|ENETRESET|ENETUNREACH|ENFILE|ENOANO|ENOATTR|ENOBUFS|ENOCSI|ENODATA|ENODEV|ENOENT|ENOEXEC|ENOKEY|ENOLCK|ENOLINK|ENOMEDIUM|ENOMEM|ENOMSG|ENONET|ENOPKG|ENOPROTOOPT|ENOSPC|ENOSR|ENOSTR|ENOSYS|ENOTBLK|ENOTCONN|ENOTDIR|ENOTEMPTY|ENOTNAM|ENOTRECOVERABLE|ENOTSOCK|ENOTSUP|ENOTTY|ENOTUNIQ|ENXIO|EOPNOTSUPP|EOVERFLOW|EOWNERDEAD|EPERM|EPFNOSUPPORT|EPIPE|EPROTO|EPROTONOSUPPORT|EPROTOTYPE|ERANGE|EREMCHG|EREMOTE|EREMOTEIO|ERESTART|ERFKILL|EROFS|ESHUTDOWN|ESOCKTNOSUPPORT|ESPIPE|ESRCH|ESRMNT|ESTALE|ESTRPIPE|ETIME|ETIMEDOUT|ETOOMANYREFS|ETXTBSY|EUCLEAN|EUNATCH|EUSERS|EWOULDBLOCK|EXDEV|EXFULL)>)?/ nextgroup=fjSyscallList contained
syn match fjSyscallList /,/ nextgroup=fjSyscall contained

syn keyword fjX11Sandbox none xephyr xorg xpra xvfb contained
syn keyword fjSeccompAction kill log ERRNO contained

syn match fjEnvVar "[A-Za-z0-9_]\+=" contained
syn match fjRmenvVar "[A-Za-z0-9_]\+" contained

syn keyword fjAll all contained
syn keyword fjNone none contained
syn keyword fjLo lo contained
syn keyword fjFilter filter contained

" Variable names (auto-generated)
syn match fjVar /\v\$\{(CFG|DESKTOP|DOCUMENTS|DOWNLOADS|HOME|MUSIC|PATH|PICTURES|RUNUSER|VIDEOS)}/

" Profile commands with 1 argument (auto-generated)
syn match fjCommand /\v(apparmor|bind|blacklist|blacklist-nolog|caps\.drop|caps\.keep|cpu|dbus-system|dbus-system\.broadcast|dbus-system\.call|dbus-system\.own|dbus-system\.see|dbus-system\.talk|dbus-user|dbus-user\.broadcast|dbus-user\.call|dbus-user\.own|dbus-user\.see|dbus-user\.talk|defaultgw|dns|env|hostname|hosts-file|ignore|include|ip|ip6|iprange|join-or-start|keep-fd|landlock\.fs\.execute|landlock\.fs\.makedev|landlock\.fs\.makeipc|landlock\.fs\.read|landlock\.fs\.write|mac|mkdir|mkfile|mtu|name|net|netfilter|netfilter6|netmask|netns|nice|noblacklist|noexec|nowhitelist|overlay-named|private|private-bin|private-cwd|private-etc|private-home|private-lib|private-opt|private-srv|protocol|read-only|read-write|restrict-namespaces|rlimit-as|rlimit-cpu|rlimit-fsize|rlimit-nofile|rlimit-nproc|rlimit-sigpending|rmenv|seccomp|seccomp-error-action|seccomp\.32|seccomp\.32\.drop|seccomp\.32\.keep|seccomp\.drop|seccomp\.keep|shell|timeout|tmpfs|veth-name|whitelist|whitelist-ro|x11|xephyr-screen) / skipwhite contained
" Profile commands with 0 arguments (auto-generated)
syn match fjCommand /\v(allow-debuggers|allusers|apparmor|apparmor-replace|apparmor-stack|caps|deterministic-exit-code|deterministic-shutdown|disable-mnt|ipc-namespace|keep-config-pulse|keep-dev-ntsync|keep-dev-shm|keep-shell-rc|keep-var-tmp|landlock\.enforce|machine-id|memory-deny-write-execute|netfilter|netlock|no3d|noautopulse|nodbus|nodvd|nogroups|noinput|nonewprivs|noprinters|noroot|nosound|notpm|notv|nou2f|novideo|overlay|overlay-tmpfs|private|private-cache|private-cwd|private-dev|private-etc|private-lib|private-tmp|quiet|restrict-namespaces|seccomp|seccomp\.block-secondary|tab|tracelog|writable-etc|writable-run-user|writable-var|writable-var-log|x11)$/ contained
syn match fjCommand /ignore / nextgroup=fjCommand,fjCommandNoCond skipwhite contained
syn match fjCommand /caps\.drop / nextgroup=fjCapability,fjAll skipwhite contained
syn match fjCommand /caps\.keep / nextgroup=fjCapability skipwhite contained
syn match fjCommand /protocol / nextgroup=fjProtocol skipwhite contained
syn match fjCommand /restrict-namespaces / nextgroup=fjNamespaces skipwhite contained
syn match fjCommand /\vseccomp(\.32)?(\.drop|\.keep)? / nextgroup=fjSyscall skipwhite contained
syn match fjCommand /x11 / nextgroup=fjX11Sandbox skipwhite contained
syn match fjCommand /env / nextgroup=fjEnvVar skipwhite contained
syn match fjCommand /rmenv / nextgroup=fjRmenvVar skipwhite contained
syn match fjCommand /shell / nextgroup=fjNone skipwhite contained
syn match fjCommand /net / nextgroup=fjNone,fjLo skipwhite contained
syn match fjCommand /ip / nextgroup=fjNone skipwhite contained
syn match fjCommand /seccomp-error-action / nextgroup=fjSeccompAction skipwhite contained
syn match fjCommand /\vdbus-(user|system) / nextgroup=fjFilter,fjNone skipwhite contained
syn match fjCommand /\vdbus-(user|system)\.(broadcast|call|own|see|talk) / skipwhite contained
" Commands that can't be inside a ?CONDITIONAL: statement
syn match fjCommandNoCond /include / skipwhite contained
syn match fjCommandNoCond /quiet$/ contained

" Conditionals (auto-generated)
syn match fjConditional /\v\?(ALLOW_TRAY|BROWSER_ALLOW_DRM|BROWSER_DISABLE_U2F|HAS_APPIMAGE|HAS_NET|HAS_NODBUS|HAS_NOSOUND|HAS_PRIVATE|HAS_X11) ?:/ nextgroup=fjCommand skipwhite contained

" A line is either a command, a conditional or a comment
syn match fjStatement /^/ nextgroup=fjCommand,fjCommandNoCond,fjConditional,fjComment

hi def link fjTodo Todo
hi def link fjComment Comment
hi def link fjCommand Statement
hi def link fjCommandNoCond Statement
hi def link fjConditional Macro
hi def link fjVar Identifier
hi def link fjCapability Type
hi def link fjProtocol Type
hi def link fjSyscall Type
hi def link fjSyscallErrno Constant
hi def link fjX11Sandbox Type
hi def link fjEnvVar Type
hi def link fjRmenvVar Type
hi def link fjAll Type
hi def link fjNone Type
hi def link fjLo Type
hi def link fjFilter Type
hi def link fjSeccompAction Type


let b:current_syntax = "firejail"
