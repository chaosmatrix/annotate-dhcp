#!no

# Copyright (C) 2017 Internet Systems Consortium, Inc. ("ISC")
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""
Kea shell unittest (python part)
"""

import unittest

from kea_conn import CARequest

class CARequestUnitTest(unittest.TestCase):
    """
    This class is dedicated to testing CARequest class. That class
    is responsible for generation of the body and headers.
    """

    def setUp(self):
        """
        This method is called before each test. Currently it does nothing.
        """
        pass

    def test_body_with_service(self):
        """
        This test verifies if the CARequest object generates the request
        content properly when there is one target service.
        """
        request = CARequest()
        request.command = "foo"
        request.service= ["service1"]
        request.generate_body()
        self.assertEqual(request.content, '{ "command": "foo", "service": ["service1"] }')

    def test_body_with_multiple_service(self):
        """
        This test verifies if the CARequest object generates the request
        content properly when there are two target service.
        """
        request = CARequest()
        request.command = "foo"
        request.service= ["service1","service2/2"]
        request.generate_body()
        self.assertEqual(request.content, '{ "command": "foo", "service": ["service1","service2/2"] }')

    def test_body_with_malformed_service(self):
        """
        This test verifies if the CARequest object generates the request
        content properly when there are two target service, one is empty
        """
        request = CARequest()
        request.command = "foo"
        request.service= ["service1",""]
        request.generate_body()
        self.assertEqual(request.content, '{ "command": "foo", "service": ["service1"] }')

    def test_body_without_args(self):
        """
        This test verifies if the CARequest object generates the request
        content properly when there are no arguments.
        """
        request = CARequest()
        request.command = "foo"
        request.generate_body()
        self.assertEqual(request.content, '{ "command": "foo" }')

    def test_body_with_args(self):
        """
        This test verifies if the CARequest object generates the request
        content properly when there are arguments.
        """
        request = CARequest()
        request.command = "foo"
        request.args = '"bar": "baz"'
        request.generate_body()
        self.assertEqual(request.content,
                         '{ "command": "foo", "arguments": { "bar": "baz" } }')

    @staticmethod
    def check_header(headers, header_name, value):
        """
        Checks if headers array contains an entry specified by
        header_name and that its value matches specified value
        """
        if header_name in headers:
            if headers[header_name] == value:
                return True
            else:
                print("Expected value: " + value +
                      " does not match actual value: " +
                      headers[header_name])
            return False
        else:
            print("Expected header: " + header_name + " missing")
            return False

    def test_headers(self):
        """
        This test checks if the headers are generated properly. Note that since
        the content is not specified, it is 0. Therefore Content-Length is 0.
        """
        request = CARequest()
        request.generate_headers()

        self.assertTrue(self.check_header(request.headers,
                                          'Content-Type', 'application/json'))
        self.assertTrue(self.check_header(request.headers,
                                          'Accept', '*/*'))
        self.assertTrue(self.check_header(request.headers,
                                          'Content-Length', '0'))

    def test_header_length(self):
        """
        This test checks if the headers are generated properly. In
        this test there is specific content of non-zero length, and
        its size should be reflected in the header.
        """
        request = CARequest()
        request.content = '{ "command": "foo" }'
        request.generate_headers()

        self.assertTrue(self.check_header(request.headers, 'Content-Length',
                                          str(len(request.content))))

    def test_header_version(self):
        """
        This test checks if the version reported in HTTP headers is
        generated properly.
        """
        request = CARequest()
        request.version = "1.2.3"
        request.generate_headers()
        self.assertTrue(self.check_header(request.headers, 'User-Agent',
                                          'Kea-shell/1.2.3'))

    def tearDown(self):
        """
        This method is called after each test. Currently it does nothing.
        """
        pass

if __name__ == '__main__':
    unittest.main()
