// RS256 서명기: 표준 입력 첫 줄 = 서명할 문자열(header.payload), 나머지 = PKCS#8 PEM 개인 키.
// 서명(base64url)만 표준 출력에 쓴다. 키는 디스크에 쓰지 않는다. (JDK 17 단일 파일 실행: java JwtSign.java)
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Base64;

public class JwtSign {
    public static void main(String[] a) throws Exception {
        BufferedReader r = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
        String data = r.readLine();
        StringBuilder pem = new StringBuilder();
        for (String l; (l = r.readLine()) != null; ) {
            if (!l.startsWith("-----")) pem.append(l.trim());
        }
        byte[] der = Base64.getDecoder().decode(pem.toString());
        PrivateKey k = KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(der));
        Signature s = Signature.getInstance("SHA256withRSA");
        s.initSign(k);
        s.update(data.getBytes(StandardCharsets.US_ASCII));
        System.out.print(Base64.getUrlEncoder().withoutPadding().encodeToString(s.sign()));
    }
}
