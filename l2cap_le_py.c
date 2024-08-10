#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <structmember.h>
//#include <stddef.h>
#include <getopt.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/l2cap.h>

// TODO make  send,recv,accept awaitable

typedef struct {
    PyObject_HEAD
    int _sock;
    uint16_t _omtu;
    // bdaddr_t _local;
    // bdaddr_t _remote;
    // int _psm;
} l2kap_le;

static PyTypeObject l2kap_le_type;

static char L2CAP_le_doc[] =
"python extension class to allow python client to talk to\n"
"macos (or ios) objc server over bluetooth L2CAP le channel.";
// untested with ios

static char init_doc[] = "create l2cap le socket";

static PyObject* L2CAP_le_init(PyObject *self, PyObject *args)
{
    l2kap_le* cinstance;
//    printf("L2CAP_le.socket\n");
    cinstance = (l2kap_le*) self;
    cinstance->_omtu=0;
    cinstance->_sock = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
    if (cinstance->_sock < 0) {
        PyErr_SetString(PyExc_IOError,"Failed to create L2CAP socket\n");
        return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static char bind_doc[] = "bind socket to local bdaddr";

static PyObject* L2CAP_le_bind(PyObject *self, PyObject *args)
{
    l2kap_le* cinstance;
    char *bdaddr_str;
    bdaddr_t src;
    struct sockaddr_l2 srcaddr;
    int dev_id = 0;
    uint16_t psm;

    if (!PyArg_ParseTuple(args, "(sH)", &bdaddr_str, &psm))
        return NULL;

    cinstance = (l2kap_le *) self;
    if (*bdaddr_str == 0) {
        hci_devba(dev_id, &src);    // use default source
    }
    else  str2ba(bdaddr_str, &src);

    memset(&srcaddr, 0, sizeof(srcaddr));
    srcaddr.l2_family = AF_BLUETOOTH;
    srcaddr.l2_bdaddr_type = BDADDR_LE_PUBLIC;
    srcaddr.l2_psm = htobs(psm);
    bacpy(&srcaddr.l2_bdaddr, &src);

    if (bind(cinstance->_sock, (struct sockaddr *)&srcaddr,
        sizeof(srcaddr)) < 0) {
        PyErr_SetString(PyExc_IOError, "Failed to bind L2CAP socket\n");
        close(cinstance->_sock);
        return NULL;
    }

    Py_INCREF(Py_None);
    return Py_None;
}

static char connect_doc[] = "connect to remote L2CAP server at bdaddr,psm";

static PyObject* L2CAP_le_connect(PyObject *self, PyObject *args)
{
    char  *bdaddr_str;
    bdaddr_t dst;
    struct sockaddr_l2 dstaddr;
    struct l2cap_options opts;
    socklen_t optlen;
    struct bt_security btsec;
    int rcvbuf;
    uint16_t psm;
    l2kap_le* cinstance;

   if (!PyArg_ParseTuple(args, "(sH)", &bdaddr_str, &psm))
        return NULL;

    cinstance = (l2kap_le *) self;

    // set security level
    memset(&btsec, 0, sizeof(btsec));
    btsec.level = BT_SECURITY_LOW;
    if (setsockopt(cinstance->_sock, SOL_BLUETOOTH, BT_SECURITY, &btsec,
		sizeof(btsec)) != 0) {
        PyErr_SetString(PyExc_IOError, "Failed to set L2CAP security level\n");
        close(cinstance->_sock);
        return NULL;
    }

    memset(&opts, 0, sizeof(opts));
    opts.omtu = 0;
    opts.imtu = 2048;
    opts.mode = 0;
    opts.fcs = 1;
    opts.txwin_size = 63;
    opts.max_tx = 3;

    if (setsockopt(cinstance->_sock, SOL_BLUETOOTH, BT_RCVMTU, &opts.imtu,
        sizeof(opts.imtu)) < 0 ) {
        PyErr_SetString(PyExc_IOError, "Failed set imtu\n");
        return NULL;
    }

    rcvbuf=2048;
    if(setsockopt(cinstance->_sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf))<0) {
        PyErr_SetString(PyExc_IOError,  "Failed set rcvbuf\n");
        close(cinstance->_sock);
        return NULL;
    }

//    optlen = sizeof(rcvbuf);
//    if (getsockopt(cinstance->_sock, SOL_SOCKET, SO_RCVBUF, &rcvbuf, &optlen) < 0) {
//        PyErr_SetString(PyExc_IOError,  "Can't get socket rcv buf size");
//        close(cinstance->_sock);
//        return NULL ;
//    }
//    printf("connect rcv buf size = %d\n", rcvbuf);
 
   // set up destination
    str2ba(bdaddr_str, &dst);
    memset(&dstaddr, 0, sizeof(dstaddr));
    dstaddr.l2_family = AF_BLUETOOTH;
    dstaddr.l2_psm = htobs(psm);
    dstaddr.l2_bdaddr_type = BDADDR_LE_PUBLIC;
    bacpy(&dstaddr.l2_bdaddr, &dst);
   // printf("connecting to %s...", bdaddr_str);
   // fflush(stdout);

     if ( connect(cinstance->_sock, (struct sockaddr *) &dstaddr,
            sizeof(dstaddr)) < 0)  {
        PyErr_SetString(PyExc_IOError, "Failed to connect\n");
        close(cinstance->_sock);
        return NULL;
    }

    //printf(" done\n");

    optlen = sizeof(opts.omtu);
    if (getsockopt(cinstance->_sock, SOL_BLUETOOTH, BT_SNDMTU, &opts.omtu,
                &optlen) < 0) {
        PyErr_SetString(PyExc_IOError, "NO get omtu\n");
        return NULL;
    }
    // printf("omtu=%d\n", opts.omtu);
    cinstance->_omtu = opts.omtu;

    Py_INCREF(Py_None);
    return Py_None;
}

static char send_doc[] = "send data to remote device";

static PyObject* L2CAP_le_send(PyObject* self, PyObject* args)
{
    l2kap_le* cinstance;
    uint8_t *data;
    int datalen, bytes_sent;

    if(!PyArg_ParseTuple(args, "y#", &data, &datalen)){
        //printf("expected bytes.\n");
        return NULL;
    }

    cinstance = (l2kap_le*) self;
    if (datalen > cinstance->_omtu)  {
       PyErr_SetString(PyExc_IOError, "len(data) excedes omtu\n");
       return NULL;
    }

    bytes_sent = send(cinstance->_sock, data, datalen, 0);
    if (bytes_sent < 0) {
        PyErr_SetString(PyExc_IOError, "send ERROR\n");
        return NULL;
     }

    return Py_BuildValue("i", bytes_sent);
}

static char recv_doc[] = "recieve data from remote device";

static PyObject* L2CAP_le_recv(PyObject* self, PyObject* args)
{
    uint8_t buff[2048];
    int bytes_received;
    l2kap_le* cinstance = (l2kap_le*) self;

    bytes_received = recv(cinstance->_sock, buff, sizeof(buff), 0);
    if (bytes_received < 0) {
        PyErr_SetString(PyExc_IOError, "recv ERROR\n");
        return NULL;
    }

    return Py_BuildValue("y#", buff, bytes_received);
}


static PyObject* L2CAP_le_listen(PyObject* self, PyObject* args)
{
    unsigned int bklg;
    l2kap_le* cinstance;
    struct l2cap_options opts;
//    int rcvbuf;

    if (!PyArg_ParseTuple(args, "I", &bklg)) {
        PyErr_SetString(PyExc_IOError, "require unsigned int param: bklg");
        return NULL;
    }

    cinstance = (l2kap_le *) self;

    memset(&opts, 0, sizeof(opts));
    opts.omtu = 0;
    opts.imtu = 2048;
    opts.mode = 0;
    opts.fcs = 1;
    opts.txwin_size = 63;
    opts.max_tx = 3;

    if (setsockopt(cinstance->_sock, SOL_BLUETOOTH, BT_RCVMTU, &opts.imtu,
        sizeof(opts.imtu)) < 0 ) {
        PyErr_SetString(PyExc_IOError, "Failed set imtu\n");
        return NULL;
    }

    if (listen(cinstance->_sock, bklg) < 0) {
        PyErr_SetString(PyExc_IOError, "cannot listen on socket\n");
        return NULL;
    }

    Py_INCREF(Py_None);
    return Py_None;
}

PyObject* L2CAP_le_accept(PyObject* self, PyObject* args)
{
    int nsk;
    l2kap_le* cinstance;
    struct sockaddr_l2 addr;
    socklen_t optlen;
    l2kap_le* noosock;
    char remote_addr[18];
    uint16_t omtu;
    int rcvbuf;

    cinstance = (l2kap_le *) self;
    optlen = sizeof(addr);
    nsk = accept(cinstance->_sock, (struct sockaddr*) &addr, &optlen);
    if (nsk < 0) {
       PyErr_SetString(PyExc_IOError, "accept gone wrong\n");
       return NULL;
    }

    noosock = PyObject_New(l2kap_le, &l2kap_le_type);
    noosock->_sock = nsk;

    rcvbuf=2048;
    if(setsockopt(nsk, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0) {
        PyErr_SetString(PyExc_IOError, "failed set rcvbuf\n");
        close(cinstance->_sock);
        return NULL;
    }

//    optlen = sizeof(rcvbuf);
//    if (getsockopt(nsk, SOL_SOCKET, SO_RCVBUF, &rcvbuf, &optlen) < 0) {
//        PyErr_SetString(PyExc_IOError,  "Can't get socket rcv buf size");
//        close(cinstance->_sock);
//        return NULL ;
//    }
//    printf("nsk rcv buf size = %d\n", rcvbuf);

    optlen = sizeof(omtu);
    if (getsockopt(nsk, SOL_BLUETOOTH, BT_SNDMTU, &omtu, &optlen) <0) {
        PyErr_SetString(PyExc_IOError, "NO get omtu");
        return NULL;
    }
    //printf("nsk omtu=%d\n", omtu);
    noosock->_omtu = omtu;

    ba2str(&addr.l2_bdaddr, remote_addr);
    return Py_BuildValue("(Os)",(PyObject*) noosock, remote_addr);
}

static PyObject* L2CAP_le_close(PyObject* self, PyObject* args)
{
    l2kap_le* cinstance = (l2kap_le*) self;
    if (close(cinstance->_sock) <0) {
       PyErr_SetString(PyExc_IOError, "close socket failed\n");
       return NULL;
    }
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef L2CAP_lemethods[] = {
    { "__init__", L2CAP_le_init, METH_VARARGS, init_doc },
    { "bind", L2CAP_le_bind, METH_VARARGS, bind_doc },
    { "connect", L2CAP_le_connect, METH_VARARGS, connect_doc },
    { "send", L2CAP_le_send, METH_VARARGS, send_doc },
    { "recv", L2CAP_le_recv, METH_VARARGS, recv_doc },
    { "listen", L2CAP_le_listen, METH_VARARGS, "listen" },
    { "accept", L2CAP_le_accept, METH_VARARGS, "accept" },
    { "close", L2CAP_le_close, METH_VARARGS, "close" },
    { NULL,NULL,0,NULL }
};


static PyMemberDef L2CAP_lemembers[] = {
    {"_sock", T_INT, offsetof(l2kap_le, _sock), READONLY, "sock fd" },
    {"_omtu", T_USHORT, offsetof(l2kap_le, _omtu), READONLY, "out max tx unit" },
    { NULL, 0, 0, 0, NULL }
};

static PyModuleDef _L2CAP_lemodule = {
	PyModuleDef_HEAD_INIT,
	"_L2CAP_le",
	NULL,
	-1,
 	L2CAP_lemethods
};


static void l2kap_le_dealloc(l2kap_le *obj)
{
    Py_TYPE(obj)->tp_free((PyObject *)obj);
}

static PyObject* l2kap_le_repr(l2kap_le *obj)
{
    return PyUnicode_FromFormat("l2cap_le socket wrapper at %p", obj);
}

static PyTypeObject l2kap_le_type = {
	PyVarObject_HEAD_INIT(&PyType_Type, 0)
	"_L2CAP_le.L2CAP_le",		/* tp_name */
	sizeof(l2kap_le),  		/* tp_basicsize */
	0,				/* tp_itemsize */
	(destructor) l2kap_le_dealloc,	/* tp_dealloc */
	0,  				/* tp_print */
	0,				/* tp_getattr */
	0,				/* tp_setattr */
	0,				/* tp_reserved */
	(reprfunc) l2kap_le_repr,	/* tp_repr */
	0,				/* tp_as_number */
	0,				/* tp_as_sequence */
	0,				/* tp_as_mapping */
	0,				/* tp_hash */
	0,				/* tp_call */
	0,				/* tp_str */
	0,				/* tp_getattro */
 	0,				/* tp_setattro */
 	0,				/* tp_as_buffer */
	Py_TPFLAGS_DEFAULT, //| Py_TPFLAGS_HAVE_GC, /* tp_flags */
	PyDoc_STR(L2CAP_le_doc),	/* tp_doc */
	0,//(traverseproc) l2kap_traverse, /* tp_traverse */
	0,//(inquiry) l2kap_clear,	/* tp_clear */
	0,				/* tp_richcompare */
	0,				/* tp_weaklistoffset */
	0,				/* tp_iter */
	0,				/* tp_iternext */
 	L2CAP_lemethods,		/* tp_methods */
	L2CAP_lemembers,		/* tp_members */
	0,				/* tp_getset */
	0,				/* tp_base */
	0,				/* tp_dict */
	0,				/* tp_descr_get */
	0,				/* tp_descr_set */
	0,				/* tp_dictoffset */
	(initproc) L2CAP_le_init,	/* tp_init */
	0,				/* tp_alloc */
	PyType_GenericNew		/* tp_new */
};

PyMODINIT_FUNC PyInit__L2CAP_le(void) {
    PyObject *module;

    module = PyModule_Create(&_L2CAP_lemodule);
    if (module==NULL)  return NULL;

    if (PyType_Ready(&l2kap_le_type) < 0)
        return NULL;

    Py_INCREF(&l2kap_le_type);
    if (PyModule_AddObject(module, "L2CAP_le", (PyObject *) &l2kap_le_type) < 0) {
        Py_DECREF(&l2kap_le_type);
        Py_DECREF(module);
        return NULL;
    }

    return module;
}
