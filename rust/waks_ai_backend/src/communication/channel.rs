use tokio::sync::mpsc;

use super::protocol::{Request, Response};

pub type RequestSender = mpsc::Sender<Request>;
pub type RequestReceiver = mpsc::Receiver<Request>;

pub type ResponseSender = mpsc::Sender<Response>;
pub type ResponseReceiver = mpsc::Receiver<Response>;

pub fn make_channels() -> (
    RequestSender,
    RequestReceiver,
    ResponseSender,
    ResponseReceiver,
) {
    let (req_tx, req_rx) = mpsc::channel(100);
    let (res_tx, res_rx) = mpsc::channel(100);
    (req_tx, req_rx, res_tx, res_rx)
}
