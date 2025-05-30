/*
 * Copyright The Microcks Authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.github.microcks.util.http;

import java.util.Collections;

import io.github.microcks.util.script.HttpHeadersStringToStringsMap;
import io.github.microcks.util.script.StringToStringsMap;
import jakarta.servlet.http.HttpServletRequest;

/**
 * Helper class containing utility to deal with Http Headers
 */
public class HttpHeadersUtil {

   private HttpHeadersUtil() {
      // Private constructor to hide the implicit public one.
   }

   /**
    * Extract headers from HttpServletRequest into a map of key-value pairs with header name to list of values.
    * 
    * @param request The original HttpServletRequest from which the headers should be extracted
    * @return A StringToStringsMap containing all headers
    */
   public static StringToStringsMap extractFromHttpServletRequest(HttpServletRequest request) {
      StringToStringsMap headers = new HttpHeadersStringToStringsMap();
      if (request != null) {
         for (String headerName : Collections.list(request.getHeaderNames())) {
            headers.put(headerName, Collections.list(request.getHeaders(headerName)));
         }
      }
      return headers;
   }

}
