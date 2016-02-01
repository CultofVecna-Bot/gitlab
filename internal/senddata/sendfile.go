/*
The xSendFile middleware transparently sends static files in HTTP responses
via the X-Sendfile mechanism. All that is needed in the Rails code is the
'send_file' method.
*/

package senddata

import (
	"../git"
	"../helper"
	"log"
	"net/http"
	"strings"
)

const (
	sendDataResponseHeader = "Gitlab-Workhorse-Send-Data"
	sendFileResponseHeader = "X-Sendfile"
)

type sendFileResponseWriter struct {
	rw       http.ResponseWriter
	status   int
	hijacked bool
	req      *http.Request
}

func NewSendFileResponseWriter(rw http.ResponseWriter, req *http.Request) sendFileResponseWriter {
	s := sendFileResponseWriter{
		rw:  rw,
		req: req,
	}
	// Advertise to upstream (Rails) that we support X-Sendfile
	req.Header.Set("X-Sendfile-Type", "X-Sendfile")
	return s
}

func (s *sendFileResponseWriter) Header() http.Header {
	return s.rw.Header()
}

func (s *sendFileResponseWriter) Write(data []byte) (n int, err error) {
	if s.status == 0 {
		s.WriteHeader(http.StatusOK)
	}
	if s.hijacked {
		return
	}
	return s.rw.Write(data)
}

func (s *sendFileResponseWriter) WriteHeader(status int) {
	if s.status != 0 {
		return
	}

	s.status = status
	if s.status != http.StatusOK {
		s.rw.WriteHeader(s.status)
		return
	}

	if file := s.Header().Get(sendFileResponseHeader); file != "" {
		s.Header().Del(sendFileResponseHeader)
		// Mark this connection as hijacked
		s.hijacked = true

		// Serve the file
		sendFileFromDisk(s.rw, s.req, file)
		return
	}
	if sendData := s.Header().Get(sendDataResponseHeader); strings.HasPrefix(sendData, git.SendBlobPrefix) {
		s.Header().Del(sendDataResponseHeader)
		s.hijacked = true
		git.SendBlob(s.rw, s.req, sendData)
		return
	}

	s.rw.WriteHeader(s.status)
	return
}

func sendFileFromDisk(w http.ResponseWriter, r *http.Request, file string) {
	log.Printf("Send file %q for %s %q", file, r.Method, r.RequestURI)
	content, fi, err := helper.OpenFile(file)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer content.Close()

	http.ServeContent(w, r, "", fi.ModTime(), content)
}

func (s *sendFileResponseWriter) Flush() {
	s.WriteHeader(http.StatusOK)
}
