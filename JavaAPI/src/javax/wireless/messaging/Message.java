package javax.wireless.messaging;

public interface Message {
    String getAddress();
    void setAddress(String addr);
    java.util.Date getTimestamp();
}
