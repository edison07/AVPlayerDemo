import XCTest
import Combine
@testable import GlossikaPlayer

final class MediaServiceTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = []
        super.tearDown()
    }
    
    // 測試 MockMediaService 成功取得假資料
    func testMockMediaServiceSuccess() {
        // 給定：使用 MockMediaService
        let service: MediaServiceProtocol = MockMediaService()
        let expectation = self.expectation(description: "成功取得假資料")
        
        // 當：呼叫 fetchMedia()
        service.fetchMedia()
            .sink { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("不應該有錯誤發生，錯誤：\(error)")
                case .finished:
                    break
                }
                expectation.fulfill()
            } receiveValue: { media in
                // 那麼：驗證資料內容
                XCTAssertEqual(media.categories.count, 2, "應該有兩個分類")
                XCTAssertEqual(media.categories[0].name, "教育", "第一個分類應該是教育")
                XCTAssertEqual(media.categories[1].name, "娛樂", "第二個分類應該是娛樂")
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
    }
    
    // 測試 MediaService 當找不到 media.json 時，應回傳 mediaNotFound 錯誤
    func testMediaServiceFailure() {
        let failingService = FailingMediaService()
        let expectation = self.expectation(description: "找不到 JSON 檔案，回傳 mediaNotFound 錯誤")
        
        // 呼叫 fetchMedia()
        failingService.fetchMedia()
            .sink { completion in
                switch completion {
                case .failure(let error):
                    // 那麼：確認錯誤為 mediaNotFound
                    if let appError = error as? AppError {
                        XCTAssertEqual(appError, AppError.mediaNotFound, "錯誤應該為 mediaNotFound")
                    } else {
                        XCTFail("錯誤類型不符")
                    }
                case .finished:
                    XCTFail("預期會有錯誤，但完成了")
                }
                expectation.fulfill()
            } receiveValue: { media in
                XCTFail("不應該收到資料，收到：\(media)")
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
    }
}
