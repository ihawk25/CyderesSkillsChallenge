{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
	  "Principal": {
        "Service": "${aws_service}.amazonaws.com"
	  },
      "Action": "sts:AssumeRole"
	}
  ]
}
