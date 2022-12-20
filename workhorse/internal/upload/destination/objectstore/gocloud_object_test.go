package objectstore

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/upload/destination/objectstore/test"
)

func TestGoCloudObjectUpload(t *testing.T) {
	mux, _ := test.SetupGoCloudFileBucket(t, "azuretest")

	ctx, cancel := context.WithCancel(context.Background())
	deadline := time.Now().Add(testTimeout)

	objectName := "test.png"
	testURL := "azuretest://azure.example.com/test-container"
	p := &GoCloudObjectParams{Ctx: ctx, Mux: mux, BucketURL: testURL, ObjectName: objectName}
	object, err := NewGoCloudObject(p)
	require.NotNil(t, object)
	require.NoError(t, err)

	// copy data
	n, err := object.Consume(ctx, strings.NewReader(test.ObjectContent), deadline)
	require.NoError(t, err)
	require.Equal(t, test.ObjectSize, n, "Uploaded file mismatch")

	bucket, err := mux.OpenBucket(ctx, testURL)
	require.NoError(t, err)

	// Verify the data was copied correctly.
	received, err := bucket.ReadAll(ctx, objectName)
	require.NoError(t, err)
	require.Equal(t, []byte(test.ObjectContent), received)

	cancel()

	testhelper.Retry(t, 5*time.Second, func() error {
		exists, err := bucket.Exists(ctx, objectName)
		require.NoError(t, err)

		if exists {
			return fmt.Errorf("file %s is still present", objectName)
		}

		return nil
	})
}
